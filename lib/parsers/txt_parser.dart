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
    r'(?:\s*$|([.．、:：]\s*|\s+)?(\S.{0,49})?)$',
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
              number: _parseNumber(explicit.group(1)!),
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
                number: _parseNumber(embedded.group(1)!),
              ),
            );
          }
        }
        continue;
      }

      final english =
          line.length <= 80 ? _englishHeadingPattern.firstMatch(line) : null;
      if (english != null) {
        candidates.add(
          _HeadingCandidate(
            start: match.start + _leadingWhitespaceLength(match.group(0)!),
            kind: _HeadingKind.chapter,
            strong: true,
            number: int.tryParse(english.group(1)!),
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

      final numeric = _numericHeading(line);
      if (numeric != null) {
        candidates.add(
          _HeadingCandidate(
            start: match.start + _leadingWhitespaceLength(match.group(0)!),
            kind: _HeadingKind.numeric,
            strong: numeric.clean,
            number: numeric.number,
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
            number: _parseNumber(embedded.group(1)!),
          ),
        );
      }
    }
    return candidates;
  }

  /// 以裸数字开头的标题行：「12」「12、重逢」「12 重逢」「十二、重逢」，
  /// 还有数字后面直接接字的「12重逢」。不是标题时返回 null。
  ///
  /// clean 表示写法干净：只有一个数字，或者是数字、分隔符再加一个短标题，
  /// 而且标题里没有逗号、句号这类句子标点。正文里以数字开头的行大多不干净，
  /// 比如「16强之后，估计……」。冒号后面跟数字的是比分或时间（「1：0」
  /// 「3:30」），不算标题。
  static ({int number, bool clean})? _numericHeading(String line) {
    if (line.length > 80) return null;
    final arabic = _arabicNumberHeadingPattern.firstMatch(line);
    if (arabic != null) {
      final title = arabic.group(3);
      if (!_looksLikeNumericHeading(title)) return null;
      if (title != null && title.startsWith(RegExp('[0-9０-９]'))) return null;
      // 「1.2 标题」这种小节编号按整数部分算。
      final number = _parseNumber(arabic.group(1)!.split('.').first);
      if (number == null) return null;
      return (
        number: number,
        clean: title == null ||
            (arabic.group(2) != null && !_looksLikeNumberedProse(title)),
      );
    }
    final chinese = _chineseNumberHeadingPattern.firstMatch(line);
    if (chinese == null) return null;
    final number = _parseNumber(chinese.group(1)!);
    if (number == null) return null;
    final title = chinese.group(2);
    return (
      number: number,
      clean: title == null || !_looksLikeNumberedProse(title),
    );
  }

  static bool _looksLikeNumberedProse(String title) =>
      title.contains(RegExp('[，,]')) ||
      _looksLikeProseTitledLine(title, strong: true);

  static const Map<String, int> _chineseDigits = {
    '零': 0,
    '〇': 0,
    '一': 1,
    '二': 2,
    '两': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
  };
  static final RegExp _chineseNumeral = RegExp(r'^[零〇一二两三四五六七八九十百千万亿]+$');
  static final RegExp _chineseUnit = RegExp('[十百千万亿]');

  /// 标题里的编号换成整数：阿拉伯数字（含全角）、「一百零三」、「一〇三」。
  /// 认不出的（「甲」「乙」、汉字和阿拉伯数字混写）返回 null。
  static int? _parseNumber(String text) {
    final value = text.replaceAllMapped(
      RegExp('[０-９]'),
      (match) => String.fromCharCode(match[0]!.codeUnitAt(0) - 0xFF10 + 0x30),
    );
    if (RegExp(r'^[0-9]+$').hasMatch(value)) return int.tryParse(value);
    if (!_chineseNumeral.hasMatch(value)) return null;
    if (!_chineseUnit.hasMatch(value)) {
      // 「一〇三」：逐位读。
      var result = 0;
      for (final char in value.split('')) {
        result = result * 10 + _chineseDigits[char]!;
      }
      return result;
    }
    var total = 0; // 万、亿以上的部分
    var section = 0; // 万以下的部分
    var digit = 0;
    for (final char in value.split('')) {
      final parsed = _chineseDigits[char];
      if (parsed != null) {
        digit = parsed;
        continue;
      }
      switch (char) {
        case '十':
          section += (digit == 0 ? 1 : digit) * 10;
        case '百':
          section += (digit == 0 ? 1 : digit) * 100;
        case '千':
          section += (digit == 0 ? 1 : digit) * 1000;
        case '万':
          total += (section + digit) * 10000;
          section = 0;
        case '亿':
          total = (total + section + digit) * 100000000;
          section = 0;
      }
      digit = 0;
    }
    return total + section + digit;
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

  /// 一本书只认一种主要的标题写法，另一种写法的标题必须接得上它的编号。
  ///
  /// 做法参考开源阅读（Legado）：它给每本书只挑一条目录规则，挑「像章节」的
  /// 命中最多的那条，从不把几种写法混在一起用。之前这里只要裸数字行够多
  /// （达到「第X章」的一成）就整批收进来，网游、竞技小说里「1：0，先下一城！」
  /// 「16强之后，……」这样的正文行于是成了一个个假章节。
  static List<_HeadingCandidate> _selectHeadings(
    List<_HeadingCandidate> candidates,
  ) {
    List<_HeadingCandidate> ofKind(_HeadingKind kind, {bool strong = false}) =>
        [
          for (final item in candidates)
            if (item.kind == kind && (!strong || item.strong)) item,
        ];

    final chapters = ofKind(_HeadingKind.chapter);
    final sections = ofKind(_HeadingKind.section);
    final numerics = ofKind(_HeadingKind.numeric);
    final strongChapters = ofKind(_HeadingKind.chapter, strong: true);
    final strongSections = ofKind(_HeadingKind.section, strong: true);
    // 序章、尾声、番外这些不论本书用哪种标题都收。
    final keywords = [
      for (final item in candidates)
        if (item.kind == _HeadingKind.special ||
            item.kind == _HeadingKind.extra)
          item,
    ];
    final volumeStarts = [
      for (final item in ofKind(_HeadingKind.volume)) item.start,
    ];

    // 带「第」「章」的标题定下的结构。有强标题（「第一章 开始」）时，没有
    // 分隔符的弱匹配多半是正文在提「第三章」，混进来会把一章劈成两半，
    // 还会造出只有标题、没有正文的空章。
    final marked = strongChapters.length >= 2
        ? strongChapters
        : strongSections.length >= 2
            ? strongSections
            : chapters.length >= 2
                ? chapters
                : sections.length >= 2
                    ? sections
                    : null;
    final numberChain = _numberChain(numerics, volumeStarts);

    // 干净的数字标题接成的一串比「第X章」还多，说明数字才是本书的标题，
    // 那几处「第X章」是正文或作者的话。
    if (marked != null &&
        _chapterLikeCount(marked) >=
            _chapterLikeCount([
              for (final item in numberChain)
                if (item.strong) item,
            ])) {
      return _byStart([
        ...marked,
        ..._continuingNumbers(marked, numerics),
        ...keywords,
      ]);
    }

    if (numberChain.length >= 2) {
      final inChain = numberChain.toSet();
      return _byStart([
        ...numberChain,
        ..._continuingNumbers(
          numberChain,
          _byStart([
            ...chapters,
            ...sections,
            for (final item in numerics)
              if (!inChain.contains(item)) item,
          ]),
        ),
        ...keywords,
      ]);
    }

    // 零星的一两个标题：一章一节，或者「第一章」后面跟着接得上的「2」。
    final loose = _byStart([...chapters, ...sections]);
    final headings = _byStart([
      ...loose,
      ..._continuingNumbers(loose, numerics),
    ]);
    if (headings.length >= 2) {
      return _byStart([...headings, ...keywords]);
    }
    // 单独下载的番外合集：没有正章，只有「番外一」「番外二」……
    if (ofKind(_HeadingKind.extra).length >= 2) return keywords;
    return const [];
  }

  /// 「像章节」的命中数：和上一个计入的标题隔开超过 [_minChapterGap] 个字
  /// 才算一次。章节之间总隔着正文，正文里成串的编号（列表、比分）挤在一起，
  /// 算不了几次。计法同开源阅读挑目录规则时的计数。
  static int _chapterLikeCount(List<_HeadingCandidate> headings) {
    var count = 0;
    int? last;
    for (final heading in headings) {
      if (last == null || heading.start - last > _minChapterGap) {
        count++;
        last = heading.start;
      }
    }
    return count;
  }

  static const int _minChapterGap = 1000;

  /// 相邻两个数字标题的编号最多差这么多：作者漏编、抓取时缺了几章，编号
  /// 会跳；正文里的数字乱跳，接不进来。
  static const int _maxNumberStep = 20;

  /// 编号接得上的最长一串数字标题：后一个比前一个大 1～[_maxNumberStep]，
  /// 隔着分卷标题（「第二卷」）时也可以从 1 重新编。
  ///
  /// 一样长的串里，取干净的标题多的；还一样，取后出现的：卷首目录里的
  /// 「1 开始」「2 继续」和正文里的那一串一样长，标题要落在正文上。
  static List<_HeadingCandidate> _numberChain(
    List<_HeadingCandidate> items,
    List<int> volumeStarts,
  ) {
    final length = List<int>.filled(items.length, 0);
    final clean = List<int>.filled(items.length, 0);
    final previous = List<int>.filled(items.length, -1);
    int compare(int a, int b) =>
        length[a] != length[b] ? length[a] - length[b] : clean[a] - clean[b];

    // 以某个编号结尾的最好的一串，最后一项的下标。
    final endingWith = <int, int>{};
    var best = -1;
    // 最近那个分卷标题之前最好的一串：卷里的编号可以接着它从 1 重新开始。
    var beforeVolume = -1;
    var volume = 0;
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      while (volume < volumeStarts.length &&
          volumeStarts[volume] < item.start) {
        beforeVolume = best;
        volume++;
      }
      final number = item.number;
      if (number == null) continue;

      var from = -1;
      for (var step = 1; step <= _maxNumberStep; step++) {
        final candidate = endingWith[number - step];
        if (candidate != null && (from < 0 || compare(candidate, from) > 0)) {
          from = candidate;
        }
      }
      if (number <= 1 &&
          beforeVolume >= 0 &&
          (from < 0 || compare(beforeVolume, from) > 0)) {
        from = beforeVolume;
      }
      length[index] = from < 0 ? 1 : length[from] + 1;
      clean[index] = (from < 0 ? 0 : clean[from]) + (item.strong ? 1 : 0);
      previous[index] = from;

      final existing = endingWith[number];
      if (existing == null || compare(index, existing) >= 0) {
        endingWith[number] = index;
      }
      if (best < 0 || compare(index, best) >= 0) best = index;
    }

    final chain = <_HeadingCandidate>[];
    for (var index = best; index >= 0; index = previous[index]) {
      chain.add(items[index]);
    }
    return chain.reversed.toList(growable: false);
  }

  /// [fillers] 里编号接得上 [anchors] 的标题：前一个标题是 N，它就得是
  /// N+1，而且小于下一个锚点的编号。「第一话 → 2 → 3 → 第四话」这种
  /// 漏写了「第」「话」的标题收进来；正文里的「1：0」「16强之后」夹在
  /// 第 143 章和第 144 章之间，接不上，不收。
  static List<_HeadingCandidate> _continuingNumbers(
    List<_HeadingCandidate> anchors,
    List<_HeadingCandidate> fillers,
  ) {
    final accepted = <_HeadingCandidate>[];
    var next = 0;
    int? previous = 0;
    for (final filler in fillers) {
      while (next < anchors.length && anchors[next].start < filler.start) {
        previous = anchors[next].number;
        next++;
      }
      final number = filler.number;
      if (number == null || previous == null || number != previous + 1) {
        continue;
      }
      final limit = next < anchors.length ? anchors[next].number : null;
      if (limit != null && number >= limit) continue;
      accepted.add(filler);
      previous = number;
    }
    return accepted;
  }

  static List<_HeadingCandidate> _byStart(List<_HeadingCandidate> headings) =>
      headings..sort((a, b) => a.start.compareTo(b.start));

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

  /// 章、节：带「第」和分隔符（「第一章 开始」）。数字标题：写法干净
  /// （「12」「12、重逢」），见 [TxtParser._numericHeading]。
  final bool strong;

  /// 标题里的编号，「第一百四十三章」是 143。序章、番外这类没有编号，
  /// 编号认不出来（「第甲章」）也是 null。
  final int? number;

  const _HeadingCandidate({
    required this.start,
    required this.kind,
    this.strong = false,
    this.number,
  });
}
