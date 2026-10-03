import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/pages/reader/paged_reader.dart';
import 'package:yunchuang/pages/reader/txt_reader.dart';

/// 中文 TXT 每段自带两个全角空格，分章时整章 trim 掉了第一段的。阅读器
/// 不看原文照加缩进的话，第一段两格、后面每段四格。
void main() {
  const content = '第一段正文。\n　　第二段正文。\n　　第三段正文。';

  int leadingIdeographicSpaces(String text) {
    var count = 0;
    while (count < text.length && text.codeUnitAt(count) == 0x3000) {
      count++;
    }
    return count;
  }

  List<int> renderedIndents(WidgetTester tester) => [
        for (final text in tester.widgetList<SelectableText>(
          find.byType(SelectableText),
        ))
          leadingIdeographicSpaces(text.textSpan!.toPlainText()),
      ];

  testWidgets('TXT scroll reader indents every paragraph the same',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TxtReader(content: content, paragraphIndent: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(renderedIndents(tester), [2, 2, 2]);
  });

  testWidgets('paged reader indents every paragraph the same', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PagedReader(content: content, paragraphIndent: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(renderedIndents(tester), [2, 2, 2]);
  });
}
