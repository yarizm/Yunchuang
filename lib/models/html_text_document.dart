import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class HtmlTextLink {
  final String href;
  final String label;
  final bool isFootnote;

  const HtmlTextLink({
    required this.href,
    required this.label,
    required this.isFootnote,
  });

  @override
  bool operator ==(Object other) =>
      other is HtmlTextLink &&
      other.href == href &&
      other.label == label &&
      other.isFootnote == isFootnote;

  @override
  int get hashCode => Object.hash(href, label, isFootnote);
}

class HtmlTextSegment {
  final String text;
  final double fontScale;
  final bool bold;
  final bool italic;
  final HtmlTextLink? link;

  const HtmlTextSegment({
    required this.text,
    this.fontScale = 1,
    this.bold = false,
    this.italic = false,
    this.link,
  });
}

class HtmlTextDocument {
  final String plainText;
  final List<HtmlTextSegment> segments;
  final Map<String, int> anchorOffsets;

  const HtmlTextDocument({
    required this.plainText,
    required this.segments,
    required this.anchorOffsets,
  });
}

class HtmlAnchorTarget {
  final String text;
  final int offset;

  const HtmlAnchorTarget({required this.text, required this.offset});
}

HtmlTextDocument parseHtmlTextDocument(String html) {
  if (html.trim().isEmpty) {
    return const HtmlTextDocument(
      plainText: '',
      segments: [],
      anchorOffsets: {},
    );
  }
  final document = html_parser.parse(html);
  final builder = _HtmlTextBuilder();
  final root = document.body ?? document;
  for (final node in root.nodes) {
    _visitHtmlNode(node, builder, const _HtmlStyle());
  }
  return builder.build();
}

String? extractHtmlAnchorText(String html, String anchor) {
  return extractHtmlAnchorTarget(html, anchor)?.text;
}

HtmlAnchorTarget? extractHtmlAnchorTarget(String html, String anchor) {
  final normalizedAnchor = _decodeUriComponent(anchor).trim();
  if (normalizedAnchor.isEmpty || html.trim().isEmpty) return null;
  final fragment = html_parser.parseFragment(html);
  for (final element in fragment.querySelectorAll('*')) {
    if (element.id == normalizedAnchor ||
        element.attributes['name'] == normalizedAnchor) {
      final text = parseHtmlTextDocument(element.outerHtml).plainText.trim();
      if (text.isEmpty) return null;
      final document = parseHtmlTextDocument(html);
      final offset = document.anchorOffsets[normalizedAnchor];
      if (offset == null) return null;
      return HtmlAnchorTarget(text: text, offset: offset);
    }
  }
  return null;
}

void _visitHtmlNode(
  dom.Node node,
  _HtmlTextBuilder builder,
  _HtmlStyle style,
) {
  if (node is dom.Text) {
    builder.addText(node.data, style);
    return;
  }
  if (node is! dom.Element) return;

  final tag = node.localName?.toLowerCase() ?? '';
  if (_ignoredElements.contains(tag)) return;
  final id = node.id.trim();
  if (id.isNotEmpty) builder.markAnchor(id);
  final name = node.attributes['name']?.trim();
  if (name != null && name.isNotEmpty) builder.markAnchor(name);
  if (tag == 'br' || tag == 'hr') {
    builder.addBreak();
    return;
  }
  if (tag == 'img') {
    builder.addText('[图片]', style.copyWith(italic: true));
    return;
  }

  final isBlock = _blockElements.contains(tag);
  if (isBlock) builder.addBreak();

  var childStyle = style;
  if (tag == 'b' || tag == 'strong') {
    childStyle = childStyle.copyWith(bold: true);
  } else if (tag == 'i' || tag == 'em') {
    childStyle = childStyle.copyWith(italic: true);
  } else if (_headingScales.containsKey(tag)) {
    childStyle = childStyle.copyWith(
      fontScale: _headingScales[tag],
      bold: true,
    );
  } else if (tag == 'a') {
    final href = node.attributes['href']?.trim();
    if (href != null && href.isNotEmpty) {
      childStyle = childStyle.copyWith(
        link: HtmlTextLink(
          href: href,
          label: _normalizeInlineLabel(node.text),
          isFootnote: _isFootnoteReference(node),
        ),
      );
    }
  }

  final preformatted = tag == 'pre';
  if (preformatted) builder.enterPreformatted();
  for (final child in node.nodes) {
    _visitHtmlNode(child, builder, childStyle);
  }
  if (preformatted) builder.exitPreformatted();
  if (isBlock) builder.addBreak();
}

bool _isFootnoteReference(dom.Element element) {
  final semantics = <String>[
    element.attributes['epub:type'] ?? '',
    element.attributes['type'] ?? '',
    element.attributes['role'] ?? '',
    element.attributes['class'] ?? '',
  ].join(' ').toLowerCase();
  return semantics.contains('noteref') ||
      semantics.contains('doc-noteref') ||
      semantics.contains('footnote-ref');
}

String _normalizeInlineLabel(String value) =>
    value.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

String _decodeUriComponent(String value) {
  try {
    return Uri.decodeComponent(value);
  } on FormatException {
    return value;
  }
}

class _HtmlStyle {
  final double fontScale;
  final bool bold;
  final bool italic;
  final HtmlTextLink? link;

  const _HtmlStyle({
    this.fontScale = 1,
    this.bold = false,
    this.italic = false,
    this.link,
  });

  _HtmlStyle copyWith({
    double? fontScale,
    bool? bold,
    bool? italic,
    HtmlTextLink? link,
  }) =>
      _HtmlStyle(
        fontScale: fontScale ?? this.fontScale,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        link: link ?? this.link,
      );

  @override
  bool operator ==(Object other) =>
      other is _HtmlStyle &&
      other.fontScale == fontScale &&
      other.bold == bold &&
      other.italic == italic &&
      other.link == link;

  @override
  int get hashCode => Object.hash(fontScale, bold, italic, link);
}

class _HtmlTextBuilder {
  final List<_MutableSegment> _segments = [];
  final Map<String, int> _anchorOffsets = {};
  final Set<String> _pendingAnchors = {};
  int _length = 0;
  int _pendingBreaks = 0;
  bool _pendingSpace = false;

  /// 待输出的空格来自源码里的换行而不是真正的空格。两边都是汉字时这个
  /// 空格要丢掉——EPUB 的 XHTML 常常按固定宽度硬换行，中文书按 HTML 规则
  /// 折成一个空格就会满篇「中文 换行」。浏览器（CSS Text 3 的段落分隔符
  /// 规则）也是这么做的。
  bool _pendingSpaceFromLineBreak = false;

  /// `<pre>` 嵌套深度。只有在里面换行才算换行，外面按 HTML 规则折成空格。
  int _preformattedDepth = 0;
  int _lastCodeUnit = -1;

  void enterPreformatted() => _preformattedDepth++;
  void exitPreformatted() => _preformattedDepth--;

  void markAnchor(String anchor) {
    if (!_anchorOffsets.containsKey(anchor)) {
      _pendingAnchors.add(anchor);
    }
  }

  void addBreak() {
    _pendingBreaks = (_pendingBreaks + 1).clamp(0, 2);
    _pendingSpace = false;
    _pendingSpaceFromLineBreak = false;
  }

  void addText(String text, _HtmlStyle style) {
    for (var index = 0; index < text.length; index++) {
      final codeUnit = text.codeUnitAt(index);
      if (codeUnit == 0x0A || codeUnit == 0x0D) {
        if (_preformattedDepth > 0) {
          addBreak();
        } else if (_pendingBreaks == 0) {
          // 源码换行不是段落边界：段落靠 <p>/<br> 划分。硬换行的 XHTML
          // （Gutenberg 一类）每行一个换行，当成换行就把每句话拆成一段。
          if (!_pendingSpace) _pendingSpaceFromLineBreak = true;
          _pendingSpace = true;
        }
      } else if (_isHorizontalWhitespace(codeUnit)) {
        if (_pendingBreaks == 0) {
          _pendingSpace = true;
          _pendingSpaceFromLineBreak = false;
        }
      } else {
        _flushPending(nextCodeUnit: codeUnit);
        _append(text[index], style);
        _lastCodeUnit = codeUnit;
      }
    }
  }

  void _flushPending({int nextCodeUnit = -1}) {
    if (_length == 0) {
      _pendingBreaks = 0;
      _pendingSpace = false;
      _pendingSpaceFromLineBreak = false;
      for (final anchor in _pendingAnchors) {
        _anchorOffsets.putIfAbsent(anchor, () => 0);
      }
      _pendingAnchors.clear();
      return;
    }
    if (_pendingBreaks > 0) {
      _append('\n' * _pendingBreaks, const _HtmlStyle());
    } else if (_pendingSpace) {
      final joinsCjk = _pendingSpaceFromLineBreak &&
          _isCjk(_lastCodeUnit) &&
          _isCjk(nextCodeUnit);
      if (!joinsCjk) _append(' ', const _HtmlStyle());
    }
    _pendingBreaks = 0;
    _pendingSpace = false;
    _pendingSpaceFromLineBreak = false;
    for (final anchor in _pendingAnchors) {
      _anchorOffsets.putIfAbsent(anchor, () => _length);
    }
    _pendingAnchors.clear();
  }

  void _append(String text, _HtmlStyle style) {
    if (_segments.isEmpty || _segments.last.style != style) {
      _segments.add(_MutableSegment(style));
    }
    _segments.last.text.write(text);
    _length += text.length;
  }

  HtmlTextDocument build() {
    for (final anchor in _pendingAnchors) {
      _anchorOffsets.putIfAbsent(anchor, () => _length);
    }
    final segments = [
      for (final segment in _segments)
        HtmlTextSegment(
          text: segment.text.toString(),
          fontScale: segment.style.fontScale,
          bold: segment.style.bold,
          italic: segment.style.italic,
          link: segment.style.link,
        ),
    ];
    return HtmlTextDocument(
      plainText: segments.map((segment) => segment.text).join(),
      segments: List.unmodifiable(segments),
      anchorOffsets: Map.unmodifiable(_anchorOffsets),
    );
  }
}

class _MutableSegment {
  final _HtmlStyle style;
  final StringBuffer text = StringBuffer();

  _MutableSegment(this.style);
}

/// 汉字、假名、谚文及全角标点——它们之间不需要空格分词。
bool _isCjk(int codeUnit) =>
    (codeUnit >= 0x2E80 && codeUnit <= 0x9FFF) ||
    (codeUnit >= 0xAC00 && codeUnit <= 0xD7AF) ||
    (codeUnit >= 0xF900 && codeUnit <= 0xFAFF) ||
    (codeUnit >= 0xFF00 && codeUnit <= 0xFFEF);

bool _isHorizontalWhitespace(int codeUnit) =>
    codeUnit == 0x09 ||
    codeUnit == 0x0B ||
    codeUnit == 0x0C ||
    codeUnit == 0x20 ||
    codeUnit == 0x00A0;

const _ignoredElements = {'script', 'style', 'noscript', 'template'};

const _blockElements = {
  'address',
  'article',
  'aside',
  'blockquote',
  'dd',
  'div',
  'dl',
  'dt',
  'figcaption',
  'figure',
  'footer',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'header',
  'li',
  'main',
  'nav',
  'ol',
  'p',
  'pre',
  'section',
  'table',
  'tbody',
  'td',
  'tfoot',
  'th',
  'thead',
  'tr',
  'ul',
};

const _headingScales = {
  'h1': 2.0,
  'h2': 1.8,
  'h3': 1.6,
  'h4': 1.4,
  'h5': 1.25,
  'h6': 1.1,
};
