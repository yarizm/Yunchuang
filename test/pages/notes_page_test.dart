import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/pages/notes/notes_page.dart';
import 'package:yunchuang/providers/database_provider.dart';
import 'package:yunchuang/providers/note_provider.dart';
import 'package:yunchuang/theme/app_theme.dart';
import 'package:yunchuang/widgets/glass_container.dart';

void main() {
  testWidgets('uses stable high-contrast surfaces for notes', (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const NotesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 页面本身不铺底：全局背景由 MainShell / GlassPageRoute 那层画，Scaffold
    // 保持主题给的透明，背景才能在每一页都看得见。卡片仍是稳定的高对比面。
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, equals(null));
    expect(AppTheme.lightTheme.scaffoldBackgroundColor, Colors.transparent);
    expect(
      tester.widgetList<GlassContainer>(find.byType(GlassContainer)),
      everyElement(
        isA<GlassContainer>()
            .having((container) => container.stable, 'stable', isTrue)
            .having((container) => container.blur, 'blur', 0),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('refreshes note tags after notes provider invalidation',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: 'Tagged Book',
            filePath: 'tagged.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    final noteId = await database.into(database.notes).insert(
          NotesCompanion.insert(
            bookId: bookId,
            content: const Value('note content'),
          ),
        );
    final oldTagId = await database.into(database.tags).insert(
          TagsCompanion.insert(name: 'old-tag'),
        );
    final newTagId = await database.into(database.tags).insert(
          TagsCompanion.insert(name: 'new-tag'),
        );
    await database.into(database.noteTags).insert(
          NoteTagsCompanion.insert(noteId: noteId, tagId: oldTagId),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('old-tag'), findsWidgets);
    expect(find.text('new-tag'), findsNothing);

    await container.read(noteServiceProvider).setTagsForNote(
      noteId,
      [newTagId],
    );
    container.invalidate(allNotesProvider);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('new-tag'), findsWidgets);
    expect(find.text('old-tag'), findsNothing);
  });

  testWidgets('deletes a note from the notes list after confirmation',
      (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: 'Delete Book',
            filePath: 'delete.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    final noteId = await database.into(database.notes).insert(
          NotesCompanion.insert(
            bookId: bookId,
            content: const Value('delete me'),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('delete me'), findsOneWidget);

    await tester.tap(find.byTooltip('删除笔记'));
    await tester.pumpAndSettle();

    expect(find.text('确定要删除这条笔记吗？'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();

    expect(await container.read(noteServiceProvider).getNoteById(noteId), null);
    expect(find.text('delete me'), findsNothing);
  });

  testWidgets('没有笔记时导出入口存在但不可用', (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const NotesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final menu = find.byKey(const Key('notes-export-menu'));
    expect(menu, findsOneWidget);
    expect(
      tester.widget<PopupMenuButton<Object?>>(menu).enabled,
      isFalse,
    );
  });

  testWidgets('有笔记时可以打开导出菜单', (tester) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);

    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: 'Exportable',
            filePath: 'exportable.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    await database.into(database.notes).insert(
          NotesCompanion.insert(
            bookId: bookId,
            content: const Value('可导出的笔记'),
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const NotesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('notes-export-menu')));
    await tester.pumpAndSettle();

    expect(find.text('导出 Markdown'), findsOneWidget);
    expect(find.text('导出 CSV'), findsOneWidget);
  });
}
