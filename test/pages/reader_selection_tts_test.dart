import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/pages/reader/epub_reader.dart';
import 'package:yunchuang/pages/reader/paged_reader.dart';
import 'package:yunchuang/pages/reader/txt_reader.dart';
import 'package:yunchuang/parsers/epub_parser.dart';

typedef _ReaderBuilder = Widget Function(
  void Function(String text, int start, int end) onTtsAction,
);

void main() {
  testWidgets('TXT first paragraph renders a two-character indent',
      (tester) async {
    await _expectFirstParagraphIndent(
      tester,
      TxtReader(
        content: '第一段内容。\n第二段内容。',
        paragraphIndent: 2,
      ),
    );
  });

  testWidgets('EPUB first paragraph renders a two-character indent',
      (tester) async {
    await _expectFirstParagraphIndent(
      tester,
      EpubReader(
        content: '<p>第一段内容。</p><p>第二段内容。</p>',
        paragraphIndent: 2,
      ),
    );
  });

  testWidgets('paged first paragraph renders a two-character indent',
      (tester) async {
    await _expectFirstParagraphIndent(
      tester,
      PagedReader(
        content: '第一段内容。\n第二段内容。',
        paragraphIndent: 2,
      ),
    );
  });

  testWidgets('TXT long paragraph continuation does not repeat its indent',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final content = List.filled(1300, '字').join();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TxtReader(
            content: content,
            fontSize: 5,
            paragraphIndent: 2,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rendered = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map(_selectableText)
        .where((text) => text.contains('字'))
        .toList();
    expect(rendered, hasLength(2));
    expect(rendered.first, startsWith('\u3000\u3000字'));
    expect(rendered.last, startsWith('字'));
  });

  testWidgets('TXT selection reports the exact chapter offset', (tester) async {
    const content = '第一段内容。\n第二段由方源开始朗读。';
    await _expectReadAloudSelection(
      tester,
      selection: '方源',
      expectedStart: content.indexOf('方源'),
      readerBuilder: (onTtsAction) => TxtReader(
        content: content,
        paragraphIndent: 2,
        onTtsAction: onTtsAction,
      ),
    );
  });

  testWidgets('EPUB selection reports the rendered plain-text offset',
      (tester) async {
    const html = '<p>第一段内容。</p><p>第二段由<strong>方源</strong>开始朗读。</p>';
    final plainText = EpubParser.stripHtml(html);
    await _expectReadAloudSelection(
      tester,
      selection: '方源',
      expectedStart: plainText.indexOf('方源'),
      readerBuilder: (onTtsAction) => EpubReader(
        content: html,
        paragraphIndent: 2,
        onTtsAction: onTtsAction,
      ),
    );
  });

  testWidgets('paged selection reports the exact chapter offset',
      (tester) async {
    const content = '第一段内容。\n第二段由方源开始朗读。';
    await _expectReadAloudSelection(
      tester,
      selection: '方源',
      expectedStart: content.indexOf('方源'),
      readerBuilder: (onTtsAction) => PagedReader(
        content: content,
        paragraphIndent: 2,
        onTtsAction: onTtsAction,
      ),
    );
  });
}

Future<void> _expectFirstParagraphIndent(
  WidgetTester tester,
  Widget reader,
) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: reader)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  final rendered = tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .map(_selectableText)
      .where((text) => text.contains('第一段内容'))
      .toList();
  expect(rendered, isNotEmpty);
  expect(rendered.first, startsWith('\u3000\u3000第一段内容'));
}

String _selectableText(SelectableText widget) {
  return widget.data ?? widget.textSpan?.toPlainText() ?? '';
}

Future<void> _expectReadAloudSelection(
  WidgetTester tester, {
  required String selection,
  required int expectedStart,
  required _ReaderBuilder readerBuilder,
}) async {
  String? selectedText;
  int? selectedStart;
  int? selectedEnd;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: readerBuilder((text, start, end) {
          selectedText = text;
          selectedStart = start;
          selectedEnd = end;
        }),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  final editableFinder = find.byWidgetPredicate(
    (widget) =>
        widget is EditableText && widget.controller.text.contains(selection),
  );
  expect(editableFinder, findsOneWidget);
  final editable = tester.widget<EditableText>(editableFinder);
  final editableState = tester.state<EditableTextState>(editableFinder);
  final localStart = editable.controller.text.indexOf(selection);
  editable.controller.selection = TextSelection(
    baseOffset: localStart,
    extentOffset: localStart + selection.length,
  );
  await tester.pump();

  final toolbar = editable.contextMenuBuilder!(
    editableState.context,
    editableState,
  ) as AdaptiveTextSelectionToolbar;
  final action = toolbar.buttonItems!.singleWhere((item) => item.label == '朗读');
  action.onPressed!.call();

  expect(selectedText, selection);
  expect(selectedStart, expectedStart);
  expect(selectedEnd, expectedStart + selection.length);
}
