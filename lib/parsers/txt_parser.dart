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
  static final RegExp _specialHeadingPattern =
      _keywordHeadingPattern('序章|序言|前言|楔子|引子|终章|尾声|后记|附录');
  static final RegExp _extraHeadingPattern =
      _keywordHeadingPattern('(?:番外|外传|外傳)[篇卷]?');

  /// 以固定词开头、不带「第」的标题行：这个词单独成行，或者后面先跟编号或
  /// 分隔符再接小标题——「番外一 春日宴」「番外2：重逢」「番外篇·婚后」
  /// 「【番外】雪夜」「番外（五）」「番外之一夜白头」「序章 风起」「尾声：归来」。
  ///
  /// 词后面直接接字的不算：「番外一直没写完」「番外明天更新」「门外传来」
  /// 「前言不搭后语」都是正文。「之」后面接「后/前/类」这些字也是叙述
  /// （「番外之后……」）。逗号不算分隔符，「番外，明天更新」是作者的话。
  static RegExp _keywordHeadingPattern(String keywords) => RegExp(
        '^[$_headingDecorations]*\\s*(?:$keywords)'
        '(?:\\s*之?\\s*第?\\s*[(（]?\\s*[$_chineseNumber]+\\s*[)）]?'
        '\\s*[章话回篇节幕]?)?'
        '(?:\\s*\$|(?:[$_headingSeparators]|之(?![后前类中外余间际]))+'
        r'(.{0,60})$)',
      );
  static const String _headingDecorations =
      r'【\[〔［《〈「『<＜(（★☆◆◇■□●○◎※#＃*＊=＝~～\-－—';
  static const String _headingSeparators =
      r'\s:：\-－_.．、·・•—~～|｜/()（）\[\]［］【】〔〕《》〈〉「」『』<>＜＞'
      r'★☆◆◇■□●○◎※#＃*＊=＝';

  /// 标题后面直接跟这些词，说明这一行是正文在提「第几章」，不是标题。
  ///
  /// 只用于没有分隔符的弱标题（「第一章开始」这种写法）：真标题后面接的
  /// 是书名或小标题，「第一章里/中的/的内容」则是叙述。
  static final RegExp _proseContinuation = RegExp(
    r'^(的|里|中|内|时|后|前|上|下|内容|情节|故事|讲述|描写|讲到|写的|说的|所|说|讲|写|是|让|把|被|和|与|及|等|之|节)',
  );

  static final RegExp _headingMarkerAtEnd = RegExp(r'[章节话回篇卷部集册]$');

  /// Parse text into chapters by detecting chapter heading patterns.
  static List<ParsedChapter> parseChapters(String text) {
    final normalized = _normalize(text);
    final candidates = _findCandidates(normalized);
    final selected = _selectHeadings(candidates);

    if (selected.isEmpty) {
      return [_fallbackChapter(normalized)];
    }

    final chapters = <ParsedChapter>[];
    final blocks = <({String title, String content})>[];
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
      blocks.add((title: title, content: content));
    }

    // 只有标题、没有正文的块：常见于卷首目录，或者作者把两个章节标题连着
    // 写、中间漏了正文。它们单独成章没有意义——打开就是一页空白，还容易和
    // 后面的真章节重名。整本书都没有正文时例外，至少把标题留下来。
    final hasBody = blocks.any((block) => block.content.trim().isNotEmpty);
    final kept = hasBody
        ? blocks.where((block) => block.content.trim().isNotEmpty)
        : blocks;
    for (final block in kept) {
      chapters.add(
        ParsedChapter(
          title: block.title.isEmpty ? '第${chapters.length + 1}章' : block.title,
          content: block.content,
          sortOrder: chapters.length,
        ),
      );
    }

    return chapters.isEmpty ? [_fallbackChapter(normalized)] : chapters;
  }

  /// 书名和作者。TXT 没有元数据，只能从第一章之前的几行猜：
  ///
  /// - 书名取第一行像样的文字：跳过纯分隔线（`------`、`＊＊＊`），去掉
  ///   「书名：」和书名号。开头就是章节标题、第一行像正文，都用
  ///   [fallbackTitle]（导入时传文件名）。
  /// - 作者先找带标签的行（作者：、著者：、文/、Author:，书名后面的
  ///   by …），去掉标签。没有标签再看书名下一行：短、不像正文、也不是别的
  ///   「键：值」，才当作者。都不像就留空——宁可空着，也不要把正文或章节
  ///   标题当成作者。
  static ParsedMetadata parseMetadata(
    String text, {
    String fallbackTitle = '未知书名',
  }) {
    final header = _headerLines(_normalize(text));
    var title = '';
    var titleIndex = -1;
    for (var index = 0; index < header.length; index++) {
      final line = header[index];
      if (_isSeparatorLine(line) || _labeledAuthor(line) != null) continue;
      final candidate = _cleanTitle(line);
      if (candidate.isNotEmpty && !_looksLikeBody(candidate)) {
        title = candidate;
        titleIndex = index;
      }
      break;
    }

    String? author;
    for (final line in header) {
      author = _labeledAuthor(line);
      if (author != null) break;
    }
    if (author == null && titleIndex >= 0) {
      for (final line in header.skip(titleIndex + 1)) {
        author = _byAuthor.firstMatch(line)?.group(1)?.trim();
        if (author != null) break;
      }
      if (author == null && titleIndex + 1 < header.length) {
        final next = header[titleIndex + 1];
        if (_looksLikeBareAuthor(next)) author = next;
      }
    }

    return ParsedMetadata(
      title: title.isEmpty ? fallbackTitle : title,
      author: author ?? '',
    );
  }

  static final RegExp _authorLabel = RegExp(
    r'^(?:作\s*者|著\s*者|作者名|原\s*著|author|written\s+by)\s*[:：]\s*(.+)$'
    r'|^文\s*[/／:：]\s*(.+)$',
    caseSensitive: false,
  );
  static final RegExp _byAuthor = RegExp(r'^by\s+(.+)$', caseSensitive: false);
  static final RegExp _titleLabel = RegExp(
    r'^(?:书名|書名|标题|標題|title)\s*[:：]\s*',
    caseSensitive: false,
  );
  static final RegExp _bookTitleMarks = RegExp(r'^[《〈「『【](.+)[》〉」』】]$');
  static final RegExp _separatorLine = RegExp(
    r'^[\p{P}\p{S}\s]+$',
    unicode: true,
  );
  static final RegExp _sectionWord = RegExp(r'(简介|介绍|提要|文案|目录|正文|前言|序言)$');

  /// 第一个章节标题之前的非空行，最多 8 行。只认带「第」的强标题、英文
  /// Chapter 和序章、楔子这类：「三部曲」这种书名不能被当成标题截断。
  static List<String> _headerLines(String text) {
    final lines = <String>[];
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (lines.length >= 8 ||
          (line.length <= 80 &&
              (_strongExplicitHeadingPattern.hasMatch(line) ||
                  _englishHeadingPattern.hasMatch(line) ||
                  _isSpecialHeading(line) ||
                  _isExtraHeading(line)))) {
        break;
      }
      lines.add(line);
    }
    return lines;
  }

  static bool _isSeparatorLine(String line) => _separatorLine.hasMatch(line);

  static bool _isSpecialHeading(String line) =>
      _isKeywordHeading(_specialHeadingPattern, line);

  static bool _isExtraHeading(String line) =>
      _isKeywordHeading(_extraHeadingPattern, line);

  static bool _isKeywordHeading(RegExp pattern, String line) {
    if (line.length > 80) return false;
    final match = pattern.firstMatch(line);
    return match != null &&
        !_looksLikeProseTitledLine(match.group(1) ?? '', strong: true);
  }

  static String? _labeledAuthor(String line) {
    final match = _authorLabel.firstMatch(line);
    if (match == null) return null;
    final value = (match.group(1) ?? match.group(2) ?? '').trim();
    return value.isEmpty || value.length > 40 ? null : value;
  }

  static String _cleanTitle(String line) {
    final unlabeled = line.replaceFirst(_titleLabel, '').trim();
    return (_bookTitleMarks.firstMatch(unlabeled)?.group(1) ?? unlabeled)
        .trim();
  }

  static bool _looksLikeBody(String line) =>
      line.length > 80 || line.contains(RegExp('[。！？]'));

  static bool _looksLikeBareAuthor(String line) =>
      line.length <= 20 &&
      !_isSeparatorLine(line) &&
      !_sectionWord.hasMatch(line) &&
      !line.contains(RegExp(r'[。！？!?：:，,]'));

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
        final suffix = explicit.group(3) ?? '';
        // 「第101章番外一」：标记后面贴着番外，没有分隔符也是正经标题。
        final strong = _strongExplicitHeadingPattern.hasMatch(line) ||
            _isExtraHeading(suffix);
        if (!_looksLikeEndMarker(suffix) &&
            !_looksLikeProseTitledLine(suffix, strong: strong)) {
          candidates.add(
            _HeadingCandidate(
              start: match.start + _leadingWhitespaceLength(match.group(0)!),
              kind: _kindForMarker(explicit.group(2)!),
              strong: strong,
            ),
          );
        }
        final embedded =
            _findEmbeddedHeading(line, explicit.end - suffix.length);
        if (embedded != null) {
          final embeddedSuffix = embedded.group(3) ?? '';
          final embeddedStrong = _strongExplicitHeadingPattern.hasMatch(
            line.substring(embedded.start),
          );
          if (!_looksLikeProseTitledLine(
            embeddedSuffix,
            strong: embeddedStrong,
          )) {
            candidates.add(
              _HeadingCandidate(
                start: match.start +
                    _leadingWhitespaceLength(match.group(0)!) +
                    embedded.start,
                kind: _kindForMarker(embedded.group(2)!),
                strong: embeddedStrong,
              ),
            );
          }
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

      if (_isSpecialHeading(line)) {
        candidates.add(
          _HeadingCandidate(
            start: match.start + _leadingWhitespaceLength(match.group(0)!),
            kind: _HeadingKind.special,
            strong: true,
          ),
        );
        continue;
      }

      if (_isExtraHeading(line)) {
        candidates.add(
          _HeadingCandidate(
            start: match.start + _leadingWhitespaceLength(match.group(0)!),
            kind: _HeadingKind.extra,
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
          !_looksLikeEndMarker(embedded.group(3)) &&
          !_looksLikeProseTitledLine(
            embedded.group(3) ?? '',
            strong: _strongExplicitHeadingPattern.hasMatch(
              line.substring(embedded.start),
            ),
          )) {
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
    if (prefix.endsWith('。') ||
        prefix.endsWith('！') ||
        prefix.endsWith('？') ||
        prefix.endsWith('!') ||
        prefix.endsWith('?')) {
      return true;
    }
    // 「第一章完第二章」这种抓取格式里，完结标记要贴着一个章节标记，
    // 不能是「读完第三章」——后者是叙述，不是上一章的结束。
    for (final end in const ['终わり', '終わり', '完']) {
      if (prefix.endsWith(end)) {
        final head =
            prefix.substring(0, prefix.length - end.length).trimRight();
        return _headingMarkerAtEnd.hasMatch(head);
      }
    }
    return false;
  }

  /// 这一行像不像正文里顺口提到「第几章」，而不是章节标题。
  ///
  /// 判据尽量保守：真标题很少带句号、分号，也很少在「第X章」后面直接接
  /// 「的/里/中/内容」这类叙述用词。短标题「第一章开始」「第一章上」不受影响。
  static bool _looksLikeProseTitledLine(
    String suffix, {
    required bool strong,
  }) {
    final title = suffix.trim();
    // 单独一个句号是旧式标题的收尾，不算句子。
    if (title == '。') return false;
    if (title.contains('。') || title.contains('；') || title.contains(';')) {
      return true;
    }
    // 问号、叹号可以收尾（「第二话 人物属性是定制的吗？」），出现在中间
    // 就说明后面还有话。
    final exclaim = title.indexOf(RegExp('[！？!?]'));
    if (exclaim >= 0 && exclaim != title.length - 1) return true;
    if (!strong) {
      // 「第一章上/中/下」是常见的分节写法，单独一个字不算叙述。
      if (title == '上' || title == '中' || title == '下') return false;
      if (title.contains('，')) return true;
      if (title.contains(RegExp('[“”「」『』]'))) return true;
      if (_proseContinuation.hasMatch(title)) return true;
    }
    return false;
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
    final extraCount =
        candidates.where((item) => item.kind == _HeadingKind.extra).length;

    Set<_HeadingKind> selectedKinds;
    _HeadingKind? strongOnlyKind;
    if (strongChapterCount >= 2) {
      selectedKinds = {
        _HeadingKind.chapter,
        if (_shouldIncludeNumeric(chapterCount, numericCount))
          _HeadingKind.numeric,
      };
      // 本书的章节标题已经由强标题（「第一章 开始」）确立，那些没有分隔符
      // 的弱匹配多半是正文在提「第三章」。混进来会把一章劈成两半，还会
      // 造出只有标题、没有正文的空章。
      strongOnlyKind = _HeadingKind.chapter;
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
    } else if (extraCount >= 2) {
      // 单独下载的番外合集：没有正章，只有「番外一」「番外二」……
      selectedKinds = const {};
    } else {
      return const [];
    }

    return candidates
        .where(
          (candidate) =>
              (selectedKinds.contains(candidate.kind) &&
                  (candidate.kind != strongOnlyKind || candidate.strong)) ||
              candidate.kind == _HeadingKind.special ||
              candidate.kind == _HeadingKind.extra,
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

  /// 番外、外传。和 [special] 一样不论本书用哪种标题都收，
  /// 另外整本只有番外（≥ 2 个）时也按它分章。
  extra,
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
