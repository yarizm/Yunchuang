import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/models/html_text_document.dart';

void main() {
  test('normalizes visible text and records exact anchor offsets', () {
    const html = '''
      <div>
        <p>正文 <a epub:type="noteref" href="#fn1">[1]</a></p>
        <aside id="fn1"><p>脚注内容</p></aside>
        <script>不可见</script>
      </div>
    ''';

    final document = parseHtmlTextDocument(html);

    expect(document.plainText, '正文 [1]\n\n脚注内容');
    expect(
      document.anchorOffsets['fn1'],
      document.plainText.indexOf('脚注内容'),
    );
    final link = document.segments
        .map((segment) => segment.link)
        .whereType<HtmlTextLink>()
        .single;
    expect(link.href, '#fn1');
    expect(link.label, '[1]');
    expect(link.isFootnote, isTrue);
  });

  test('extracts decoded id and name anchors from the full document', () {
    const html = '''
      <p>开头</p>
      <section id="note%20one"><p>错误目标</p></section>
      <section id="note one"><p>正确脚注</p></section>
    ''';

    final target = extractHtmlAnchorTarget(html, 'note%20one');

    expect(target?.text, '正确脚注');
    expect(
        target?.offset, parseHtmlTextDocument(html).plainText.indexOf('正确脚注'));
  });
}
