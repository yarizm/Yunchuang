import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/book_dao.dart';
import 'package:yunchuang/database/daos/dictionary_dao.dart';
import 'package:yunchuang/database/daos/vocabulary_dao.dart';
import 'package:yunchuang/providers/ai/ai_book_content_service.dart';
import 'package:yunchuang/services/dictionary_service.dart';
import 'package:yunchuang/services/vocabulary_service.dart';
import 'package:yunchuang/widgets/vocabulary_lookup_sheet.dart';

void main() {
  testWidgets('loads local occurrences and saves a folded vocabulary entry',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final dao = VocabularyDao(database);
    final service = VocabularyService(
      dao,
      AIBookContentService(BookDao(database)),
    );
    final dictionaryDao = DictionaryDao(database);
    final dictionaryService = _FakeDictionaryService(dictionaryDao);
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: '测试书',
            filePath: 'book.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    final chapterId = await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            title: '第一章',
            content: const Value('方源醒来，方源看向窗外。'),
            contentIndex: 0,
            sortOrder: 0,
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => VocabularyLookupSheet.show(
                context,
                service: service,
                dictionaryService: dictionaryService,
                bookId: bookId,
                chapterId: chapterId,
                term: '方源',
                contextText: '方源醒来。',
                positionStart: 0,
                positionEnd: 2,
              ),
              child: const Text('打开查词'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开查词'));
    await tester.pumpAndSettle();

    expect(find.text('方源'), findsOneWidget);
    expect(find.text('2 处'), findsOneWidget);
    expect(find.text('本地查词与生词记录'), findsOneWidget);
    expect(find.text('测试离线词典 · 方源'), findsOneWidget);
    expect(find.text('本地词典释义'), findsOneWidget);

    await tester.tap(find.text('填入我的释义'));
    await tester.pump();
    final definitionField = tester.widget<TextField>(
      find.byKey(const Key('vocabulary-definition-field')),
    );
    expect(definitionField.controller?.text, '本地词典释义');
    await tester.enterText(
      find.byKey(const Key('vocabulary-definition-field')),
      '本书主角',
    );
    await tester.tap(find.byKey(const Key('save-vocabulary-entry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final saved = await dao.findForBook(bookId, '方源');
    expect(saved?.definition, '本书主角');
    expect(saved?.contextText, '方源醒来。');
    expect(find.byType(VocabularyLookupSheet), findsNothing);
  });
}

class _FakeDictionaryService extends DictionaryService {
  _FakeDictionaryService(super.dao);

  @override
  Future<DictionaryLookupResult> lookup(String term, {int limit = 8}) async {
    return const DictionaryLookupResult(
      installedSourceCount: 1,
      enabledSourceCount: 1,
      definitions: [
        DictionaryDefinition(
          sourceId: 1,
          sourceName: '测试离线词典',
          headword: '方源',
          definition: '本地词典释义',
        ),
      ],
    );
  }
}
