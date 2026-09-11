import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/vocabulary_dao.dart';
import 'package:yunchuang/pages/settings/vocabulary_page.dart';
import 'package:yunchuang/services/vocabulary_service.dart';

void main() {
  testWidgets('shows, searches, and clears vocabulary results', (tester) async {
    final now = DateTime(2026, 7, 30);
    final details = VocabularyEntryDetails(
      entry: VocabularyEntry(
        id: 1,
        bookId: 1,
        chapterId: 2,
        term: '方源',
        normalizedTerm: '方源',
        definition: '本书主角',
        contextText: '方源向前走去。',
        positionStart: 0,
        positionEnd: 2,
        createdAt: now,
        updatedAt: now,
      ),
      bookTitle: '测试书',
      chapterTitle: '第一章',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allVocabularyEntriesProvider.overrideWith(
            (ref) => Stream.value([details]),
          ),
        ],
        child: const MaterialApp(home: VocabularyPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('方源'), findsOneWidget);
    expect(find.text('本书主角'), findsOneWidget);
    expect(find.text('测试书 · 第一章'), findsOneWidget);
    expect(find.byTooltip('更多操作'), findsOneWidget);
    expect(find.byKey(const Key('vocabulary-export-menu')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('vocabulary-search-field')),
      '不存在',
    );
    await tester.pump();
    expect(find.text('没有匹配结果'), findsOneWidget);

    await tester.tap(find.byTooltip('清除'));
    await tester.pump();
    expect(find.text('方源'), findsOneWidget);
  });
}
