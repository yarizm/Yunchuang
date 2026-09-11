import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/pages/settings/dictionary_page.dart';
import 'package:yunchuang/providers/database_provider.dart';

void main() {
  testWidgets('shows imported dictionaries and StarDict help', (tester) async {
    final source = DictionarySource(
      id: 1,
      name: '英汉离线词典',
      description: '测试描述',
      formatVersion: '2.4.2',
      sameTypeSequence: 'm',
      dataFilePath: 'dictionary.dict',
      entryCount: 120000,
      enabled: true,
      isReady: true,
      createdAt: DateTime(2026, 7, 30),
      updatedAt: DateTime(2026, 7, 30),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictionarySourcesProvider.overrideWith(
            (ref) => Stream.value([source]),
          ),
        ],
        child: const MaterialApp(home: DictionaryPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('英汉离线词典'), findsOneWidget);
    expect(find.textContaining('120000 个词条'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.byKey(const Key('import-stardict-button')), findsOneWidget);

    await tester.tap(find.byTooltip('导入说明'));
    await tester.pumpAndSettle();
    expect(find.text('导入 StarDict'), findsWidgets);
    expect(find.textContaining('.dict.dz'), findsOneWidget);
    expect(find.textContaining('完全在本地进行'), findsOneWidget);
  });
}
