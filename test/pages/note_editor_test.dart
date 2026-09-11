import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/pages/notes/note_editor.dart';
import 'package:yunchuang/providers/database_provider.dart';
import 'package:yunchuang/providers/note_provider.dart';

/// 编辑器挂在一个能真的 pop 出去的导航栈上，这样返回被拦住 / 放行都看得到。
class _Harness {
  final AppDatabase database;
  final ProviderContainer container;
  late final int noteId;

  _Harness(this.database, this.container);

  static Future<_Harness> create({String content = 'draft'}) async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    final harness = _Harness(database, container);
    final bookId = await database.into(database.books).insert(
          BooksCompanion.insert(
            title: 'Book',
            filePath: 'book.txt',
            format: 'txt',
            fileSize: 1,
          ),
        );
    harness.noteId = await database.into(database.notes).insert(
          NotesCompanion.insert(
            bookId: bookId,
            content: Value(content),
          ),
        );
    return harness;
  }

  Future<void> open(WidgetTester tester, {int? noteId}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NoteEditor(noteId: noteId ?? this.noteId),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('leaving without changes pops straight away', (tester) async {
    final harness = await _Harness.create();
    await harness.open(tester);
    expect(find.text('编辑笔记'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('编辑笔记'), findsNothing);
    expect(find.text('放弃修改？'), findsNothing);
  });

  testWidgets('unsaved edits are guarded by a discard prompt', (tester) async {
    final harness = await _Harness.create();
    await harness.open(tester);

    await tester.enterText(find.byType(TextField), 'changed');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 拦住了：还在编辑页，弹出了确认。
    expect(find.text('放弃修改？'), findsOneWidget);
    expect(find.text('编辑笔记'), findsOneWidget);

    // 「继续编辑」留在原地，内容不丢。
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('编辑笔记'), findsOneWidget);
    expect(find.text('changed'), findsOneWidget);

    // 「放弃」才真的走，而且库里还是旧内容。
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃'));
    await tester.pumpAndSettle();
    expect(find.text('编辑笔记'), findsNothing);
    final note =
        await harness.container.read(noteServiceProvider).getNoteById(
              harness.noteId,
            );
    expect(note?.content, 'draft');
  });

  testWidgets('save persists and leaves without prompting', (tester) async {
    final harness = await _Harness.create();
    await harness.open(tester);

    await tester.enterText(find.byType(TextField), 'saved text');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('放弃修改？'), findsNothing);
    expect(find.text('编辑笔记'), findsNothing);
    final note =
        await harness.container.read(noteServiceProvider).getNoteById(
              harness.noteId,
            );
    expect(note?.content, 'saved text');
  });

  testWidgets('a tag can be created from the editor and is selected',
      (tester) async {
    final harness = await _Harness.create();
    await harness.open(tester);

    expect(find.text('还没有标签。新建后可以在笔记列表里按标签筛选。'),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('note-editor-new-tag')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '标签名称'), '想法');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    final chip = tester.widget<FilterChip>(find.widgetWithText(FilterChip, '想法'));
    expect(chip.selected, isTrue);

    // 新建标签本身不算保存；保存后才落到笔记上。
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final tags = await harness.container
        .read(noteServiceProvider)
        .getTagsForNote(harness.noteId);
    expect(tags.map((t) => t.name), ['想法']);
  });

  testWidgets('long-pressing a tag deletes it after confirmation',
      (tester) async {
    final harness = await _Harness.create();
    final service = harness.container.read(noteServiceProvider);
    final tag = await service.ensureTag('临时');
    await service.setTagsForNote(harness.noteId, [tag.id]);
    await harness.open(tester);

    await tester.longPress(find.widgetWithText(FilterChip, '临时'));
    await tester.pumpAndSettle();
    expect(find.text('删除标签「临时」'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, '临时'), findsNothing);
    expect(await service.getAllTags(), isEmpty);
    // 标签没了不算「未保存的改动」，返回不该再问。
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('放弃修改？'), findsNothing);
    expect(find.text('编辑笔记'), findsNothing);
  });

  testWidgets('a note that no longer exists shows a way back',
      (tester) async {
    final harness = await _Harness.create();
    await harness.open(tester, noteId: 424242);

    expect(find.text('笔记不存在'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    expect(find.text('笔记不存在'), findsNothing);
  });
}
