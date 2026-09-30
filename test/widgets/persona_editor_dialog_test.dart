import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/widgets/ai_chat/persona_editor_dialog.dart';

AiPersona _persona({
  String systemPrompt = '保持温和克制的语气。',
  String documentMarkdown = '# 林黛玉人格\n\n多愁善感，言辞机敏。',
}) {
  return AiPersona(
    id: 1,
    name: '林黛玉人格',
    type: 'character',
    characterName: '林黛玉',
    systemPrompt: systemPrompt,
    documentMarkdown: documentMarkdown,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

/// 打开编辑器，返回它关闭时给出的结果。
Future<({Future<PersonaEditDraft?> result})> _open(
  WidgetTester tester,
  AiPersona persona, {
  bool startInEditMode = false,
}) async {
  late Future<PersonaEditDraft?> result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              result = showPersonaEditorDialog(
                context,
                persona: persona,
                startInEditMode: startInEditMode,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (result: result);
}

void main() {
  testWidgets('编辑后保存，返回去掉首尾空白的草稿', (tester) async {
    final dialog = await _open(tester, _persona());

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '人格名称'),
      '  黛玉  ',
    );
    await tester.tap(find.byKey(const Key('persona-editor-save')));
    await tester.pumpAndSettle();

    final draft = await dialog.result;
    expect(draft, isNotNull);
    expect(draft!.name, '黛玉');
    expect(draft.systemPrompt, '保持温和克制的语气。');
    expect(draft.documentMarkdown, '# 林黛玉人格\n\n多愁善感，言辞机敏。');
  });

  testWidgets('提示词和文档都清空时，错误显示在输入框下面且不关闭', (tester) async {
    final dialog = await _open(tester, _persona(), startInEditMode: true);

    await tester.enterText(find.widgetWithText(TextFormField, '系统提示词'), '');
    await tester.enterText(
      find.widgetWithText(TextFormField, '人格 Markdown 文档'),
      '',
    );
    await tester.tap(find.byKey(const Key('persona-editor-save')));
    await tester.pumpAndSettle();

    expect(find.text('系统提示词和人格文档不能同时为空'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(await dialog.result, isNull);
  });

  testWidgets('提示词很长时预览可以滚动，不会撑爆对话框', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _open(
      tester,
      _persona(
        systemPrompt: List.filled(120, '请始终保持温和克制的语气回答。').join(),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('人格文档'),
      200,
      // 第一个是预览 ListView 自己的；后面还有 SelectableText 内部的。
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('persona-preview')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('人格文档'), findsOneWidget);
  });
}
