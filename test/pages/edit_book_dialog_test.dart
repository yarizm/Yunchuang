import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/pages/home/edit_book_dialog.dart';
import 'package:yunchuang/providers/database_provider.dart';

void main() {
  testWidgets('edits series name and volume order', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: 'Book',
            filePath: 'book.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    final book = await database.select(database.books).getSingle();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => EditBookDialog(book: book),
                  ),
                  child: const Text('编辑'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '系列名'),
      '长篇系列',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '系列卷序'),
      '2.5',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    final updated = await (database.select(database.books)
          ..where((row) => row.id.equals(bookId)))
        .getSingle();
    expect(updated.seriesName, '长篇系列');
    expect(updated.seriesIndex, 2.5);
  });
}
