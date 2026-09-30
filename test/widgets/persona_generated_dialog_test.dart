import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/widgets/ai_chat/persona_generated_dialog.dart';

final _persona = AiPersona(
  id: 7,
  name: '林黛玉人格',
  type: 'character',
  characterName: '林黛玉',
  systemPrompt: '',
  documentMarkdown: '# 林黛玉人格',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<({Future<PersonaGeneratedAction?> result})> _open(
  WidgetTester tester,
  AiPersona? persona,
) async {
  late Future<PersonaGeneratedAction?> result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              result = showPersonaGeneratedDialog(
                context,
                persona: persona,
                fallbackName: '林黛玉 人格',
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
  testWidgets('「查看并编辑」和「立即启用」返回对应的动作', (tester) async {
    var dialog = await _open(tester, _persona);
    expect(find.text('林黛玉人格'), findsOneWidget);
    await tester.tap(find.byKey(const Key('persona-generation-view')));
    await tester.pumpAndSettle();
    expect(await dialog.result, PersonaGeneratedAction.view);

    dialog = await _open(tester, _persona);
    await tester.tap(find.byKey(const Key('persona-generation-use')));
    await tester.pumpAndSettle();
    expect(await dialog.result, PersonaGeneratedAction.use);
  });

  testWidgets('找不到生成的人格时只留「稍后再说」', (tester) async {
    final dialog = await _open(tester, null);

    expect(find.text('林黛玉 人格'), findsOneWidget);
    expect(find.byKey(const Key('persona-generation-view')), findsNothing);
    expect(find.byKey(const Key('persona-generation-use')), findsNothing);

    await tester.tap(find.text('稍后再说'));
    await tester.pumpAndSettle();
    expect(await dialog.result, isNull);
  });
}
