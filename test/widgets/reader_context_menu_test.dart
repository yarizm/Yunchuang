import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/widgets/reader_context_menu.dart';

void main() {
  test('display-only indentation is removed from selected text and offsets',
      () {
    const renderedText = '\u3000\u3000方源';
    final selected = readerSelectedRange(
      renderedText: renderedText,
      selection: const TextSelection(baseOffset: 0, extentOffset: 4),
      leadingTextLength: 2,
    );

    expect(selected.text, '方源');
    expect(selected.start, 0);
    expect(selected.end, 2);
  });

  testWidgets('read aloud action forwards the selected text and offsets',
      (tester) async {
    const content = '开头内容。方源从这里开始朗读。';
    final controller = TextEditingController(text: content);
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditableText(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 18),
            cursorColor: Colors.blue,
            backgroundCursorColor: Colors.grey,
          ),
        ),
      ),
    );

    final start = content.indexOf('方源');
    final end = start + '方源'.length;
    controller.selection = TextSelection(baseOffset: start, extentOffset: end);
    await tester.pump();
    final editableState =
        tester.state<EditableTextState>(find.byType(EditableText));
    String? selectedText;
    int? selectedStart;
    int? selectedEnd;
    String? vocabularyText;
    int? vocabularyStart;
    int? vocabularyEnd;
    String? translatedText;

    final items = buildReaderContextMenuItems(
      editableTextState: editableState,
      onReadAloud: (text, actionStart, actionEnd) {
        selectedText = text;
        selectedStart = actionStart;
        selectedEnd = actionEnd;
      },
      onVocabulary: (text, actionStart, actionEnd) {
        vocabularyText = text;
        vocabularyStart = actionStart;
        vocabularyEnd = actionEnd;
      },
      onTranslate: (text) => translatedText = text,
    );
    final readAloud = items.singleWhere((item) => item.label == '朗读');
    readAloud.onPressed!.call();
    controller.selection = TextSelection(baseOffset: start, extentOffset: end);
    final vocabulary = items.singleWhere((item) => item.label == '查词');
    vocabulary.onPressed!.call();
    controller.selection = TextSelection(baseOffset: start, extentOffset: end);
    final translate = items.singleWhere((item) => item.label == '翻译');
    translate.onPressed!.call();

    expect(selectedText, '方源');
    expect(selectedStart, start);
    expect(selectedEnd, end);
    expect(vocabularyText, '方源');
    expect(vocabularyStart, start);
    expect(vocabularyEnd, end);
    expect(translatedText, '方源');
  });
}
