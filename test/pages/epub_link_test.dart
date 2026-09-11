import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/models/html_text_document.dart';
import 'package:yunchuang/pages/reader/epub_reader.dart';
import 'package:yunchuang/pages/reader/reader_overlays.dart';
import 'package:yunchuang/parsers/epub_parser.dart';

void main() {
  testWidgets('EPUB rendering preserves offsets across visual paragraph gaps',
      (tester) async {
    const html = '''
      <div>
        <p>第一段 <strong>正文</strong></p>
        <p>第二段<a epub:type="noteref" href="#fn1">[1]</a></p>
        <aside id="fn1"><p>脚注内容</p></aside>
      </div>
    ''';
    final sourceText = EpubParser.stripHtml(html);
    final footnoteStart = sourceText.indexOf('脚注内容');
    HtmlTextLink? tappedLink;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubReader(
            content: html,
            // 显式取消缩进：本例断言渲染文本与源文本逐字相等，缩进前缀会让
            // 断言随默认值变化而失败。缩进不影响偏移由下一个用例单独保证。
            paragraphIndent: 0,
            locatorHighlightStart: footnoteStart,
            locatorHighlightEnd: footnoteStart + '脚注内容'.length,
            onLinkTap: (link) => tappedLink = link,
          ),
        ),
      ),
    );

    final renderedText = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((widget) => widget.textSpan?.toPlainText() ?? '')
        .join();
    expect(renderedText, sourceText.replaceAll('\n', ''));

    final renderedSpans = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .expand((widget) => (widget.textSpan as TextSpan).children!)
        .whereType<TextSpan>();
    final footnoteSpan =
        renderedSpans.singleWhere((span) => span.text == '脚注内容');
    expect(footnoteSpan.style?.backgroundColor, isNotNull);

    final linkSpan = renderedSpans.singleWhere((span) => span.text == '[1]');
    (linkSpan.recognizer as TapGestureRecognizer).onTap?.call();

    expect(tappedLink?.href, '#fn1');
    expect(tappedLink?.isFootnote, isTrue);
  });

  testWidgets('footnote sheet closes in place or requests a text jump',
      (tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await ReaderOverlays.showEpubFootnote(
                  context,
                  text: '脚注正文',
                  label: '脚注 [1]',
                );
              },
              child: const Text('打开脚注'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开脚注'));
    await tester.pumpAndSettle();
    expect(find.text('脚注正文'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭脚注'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('打开脚注'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('在正文中打开'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('paragraph indent shifts rendering only, never source offsets',
      (tester) async {
    const html = '''
      <div>
        <p>第一段 <strong>正文</strong></p>
        <p>第二段<a epub:type="noteref" href="#fn1">[1]</a></p>
        <aside id="fn1"><p>脚注内容</p></aside>
      </div>
    ''';
    final sourceText = EpubParser.stripHtml(html);
    // 偏移取自源文本，不含任何缩进前缀——笔记、AI 引用和搜索定位都是这样存的。
    final footnoteStart = sourceText.indexOf('脚注内容');
    HtmlTextLink? tappedLink;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EpubReader(
            content: html,
            paragraphIndent: 2,
            locatorHighlightStart: footnoteStart,
            locatorHighlightEnd: footnoteStart + '脚注内容'.length,
            onLinkTap: (link) => tappedLink = link,
          ),
        ),
      ),
    );

    final renderedText = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((widget) => widget.textSpan?.toPlainText() ?? '')
        .join();
    // 渲染文本确实多了缩进……
    expect(renderedText, contains('　　'));
    expect(
      renderedText.replaceAll('　', ''),
      sourceText.replaceAll('\n', ''),
    );

    final renderedSpans = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .expand((widget) => (widget.textSpan as TextSpan).children!)
        .whereType<TextSpan>();

    // ……但按源文本偏移下发的高亮仍然精确落在原词上，说明缩进没有参与偏移计算。
    final footnoteSpan =
        renderedSpans.singleWhere((span) => span.text == '脚注内容');
    expect(footnoteSpan.style?.backgroundColor, isNotNull);

    // 缩进前缀本身不得被高亮。
    for (final span in renderedSpans.where((s) => s.text == '　　')) {
      expect(span.style?.backgroundColor, isNull);
    }

    final linkSpan = renderedSpans.singleWhere((span) => span.text == '[1]');
    (linkSpan.recognizer as TapGestureRecognizer).onTap?.call();
    expect(tappedLink?.href, '#fn1');
    expect(tappedLink?.isFootnote, isTrue);
  });
}
