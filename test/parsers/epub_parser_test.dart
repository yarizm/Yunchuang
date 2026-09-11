import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/parsers/epub_parser.dart';

void main() {
  group('EpubParser.stripHtml', () {
    test('strips HTML tags and preserves text', () {
      expect(EpubParser.stripHtml('<p>Hello <b>world</b></p>'), 'Hello world');
    });

    test('strips nested HTML tags', () {
      expect(
        EpubParser.stripHtml('<div><p><em>nested</em> text</p></div>'),
        'nested text',
      );
    });

    test('decodes &amp; entity to &', () {
      expect(EpubParser.stripHtml('a &amp; b'), 'a & b');
    });

    test('decodes decimal and hexadecimal character references', () {
      expect(
        EpubParser.stripHtml('&#26041;&#28304; / &#x65B9;&#x6E90;'),
        '方源 / 方源',
      );
    });

    test('decodes &nbsp; entity to space', () {
      expect(EpubParser.stripHtml('a&nbsp;b'), 'a b');
    });

    test('decodes &lt; and &gt; entities', () {
      expect(EpubParser.stripHtml('1 &lt; 2 &gt; 0'), '1 < 2 > 0');
    });

    // 源码里的换行按 HTML 规则折成一个空格。Gutenberg 一类 EPUB 的 XHTML
    // 按固定宽度硬换行，之前把它当成换行，每一行都成了一段。
    test('source newlines inside a paragraph collapse to one space', () {
      expect(
        EpubParser.stripHtml('<p>said Miss Lucas. “I am going\nto open\n\n'
            'the instrument.”</p>'),
        'said Miss Lucas. “I am going to open the instrument.”',
      );
      expect(EpubParser.stripHtml('a\n\n\nb'), 'a b');
    });

    test('a newline between two CJK characters inserts nothing', () {
      expect(EpubParser.stripHtml('<p>此开卷第一回也。作者\n自云：因曾\n历过</p>'),
          '此开卷第一回也。作者自云：因曾历过');
      // 中英混排时保留空格，不然单词会粘在汉字上。
      expect(EpubParser.stripHtml('<p>Flutter\n框架</p>'), 'Flutter 框架');
      // 真正的空格（不是换行）照旧保留。
      expect(EpubParser.stripHtml('<p>中文 空格</p>'), '中文 空格');
    });

    test('pre keeps its newlines', () {
      expect(EpubParser.stripHtml('<pre>a\nb\n\nc</pre>'), 'a\nb\n\nc');
      expect(EpubParser.stripHtml('<pre>x\ny</pre><p>m\nn</p>'), 'x\ny\n\nm n');
    });

    test('preserves readable block boundaries and line breaks', () {
      expect(
        EpubParser.stripHtml('<p>第一段</p><p>第二段<br>下一行</p>'),
        '第一段\n\n第二段\n下一行',
      );
    });

    test('omits non-visible script style and template content', () {
      expect(
        EpubParser.stripHtml(
          '<style>.hidden{}</style><p>正文</p>'
          '<script>ignore()</script><template>隐藏模板</template>',
        ),
        '正文',
      );
    });

    test('batch stripping preserves order through the isolate path', () async {
      final result = await EpubParser.stripHtmlBatch(
        [
          '<p>&#31532;&#19968;&#31456;</p>',
          '<p>第二章<br>正文</p>',
        ],
        isolateThresholdChars: 0,
      );

      expect(result, ['第一章', '第二章\n正文']);
    });

    test('trims leading and trailing whitespace', () {
      expect(EpubParser.stripHtml('  <p>hello</p>  '), 'hello');
    });

    test('handles empty string', () {
      expect(EpubParser.stripHtml(''), '');
    });

    test('handles string with only tags', () {
      expect(EpubParser.stripHtml('<br/><hr/>'), '');
    });
  });

  group('EpubParser.resolveChapterHref', () {
    const chapterFiles = [
      'OEBPS/Text/chapter-1.xhtml',
      'OEBPS/Text/chapter-2.xhtml',
      'OEBPS/Notes/notes.xhtml',
    ];

    test('resolves same-chapter fragments without a file lookup', () {
      final target = EpubParser.resolveChapterHref(
        chapterFiles,
        1,
        '#section%202',
      );

      expect(target?.chapterIndex, 1);
      expect(target?.anchor, 'section 2');
    });

    test('resolves relative cross-chapter paths and anchors', () {
      final target = EpubParser.resolveChapterHref(
        chapterFiles,
        0,
        '../Notes/notes.xhtml#fn-12',
      );

      expect(target?.chapterIndex, 2);
      expect(target?.anchor, 'fn-12');
    });

    test('rejects external and ambiguous missing targets', () {
      expect(
        EpubParser.resolveChapterHref(
          chapterFiles,
          0,
          'https://example.com/note',
        ),
        isNull,
      );
      expect(
        EpubParser.resolveChapterHref(
          chapterFiles,
          0,
          'missing.xhtml#note',
        ),
        isNull,
      );
    });
  });
}
