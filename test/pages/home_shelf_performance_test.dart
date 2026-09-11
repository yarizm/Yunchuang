import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/pages/home/book_card.dart';
import 'package:yunchuang/pages/home/home_page.dart';
import 'package:yunchuang/providers/database_provider.dart';
import 'package:yunchuang/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a 1000-book shelf only builds visible grid items',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    await database.batch((batch) {
      batch.insertAll(
        database.books,
        [
          for (var index = 0; index < 1000; index++)
            BooksCompanion.insert(
              title: 'Book $index',
              filePath: 'book-$index.txt',
              format: 'txt',
              fileSize: 1,
            ),
        ],
      );
    });
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BookCard).evaluate().length, lessThan(30));
    expect(find.text('Book 999'), findsOneWidget);
    expect(find.text('Book 0'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
