import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/note_dao.dart';
import 'package:yunchuang/parsers/csv_importer.dart';
import 'package:yunchuang/services/note_service.dart';

void main() {
  test('empty note imports do not create placeholder books', () async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = NoteService(NoteDao(database), database);

    final count = await service.importNotes([]);

    expect(count, 0);
    expect(await database.select(database.books).get(), isEmpty);
    expect(await database.select(database.notes).get(), isEmpty);
  });

  test('imports notes and normalized tags in one placeholder book', () async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = NoteService(NoteDao(database), database);

    final count = await service.importNotes([
      ImportedNote(
        selectedText: 'one',
        tags: [' tag ', 'tag', ''],
      ),
      ImportedNote(
        content: 'two',
        tags: ['tag', 'other'],
      ),
    ]);

    expect(count, 2);
    expect(await database.select(database.books).get(), hasLength(1));
    expect(await database.select(database.notes).get(), hasLength(2));
    final tags = await database.select(database.tags).get();
    expect(tags.map((tag) => tag.name), unorderedEquals(['tag', 'other']));
    expect(await database.select(database.noteTags).get(), hasLength(3));
  });

  test('reuses matching existing tags without touching unrelated tags',
      () async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = NoteService(NoteDao(database), database);

    final existingTagId = await database.into(database.tags).insert(
          TagsCompanion.insert(name: 'existing'),
        );
    await database.into(database.tags).insert(
          TagsCompanion.insert(name: 'unrelated'),
        );

    final count = await service.importNotes([
      ImportedNote(content: 'one', tags: ['existing', 'new']),
      ImportedNote(content: 'two', tags: ['new']),
    ]);

    expect(count, 2);
    final tags = await database.select(database.tags).get();
    expect(
      tags.map((tag) => tag.name),
      unorderedEquals(['existing', 'unrelated', 'new']),
    );
    final noteTags = await database.select(database.noteTags).get();
    expect(noteTags, hasLength(3));
    expect(noteTags.where((row) => row.tagId == existingTagId), hasLength(1));
  });

  group('ensureTag', () {
    test('creates a tag on first use and reuses it afterwards', () async {
      final database = AppDatabase.connect(NativeDatabase.memory());
      addTearDown(database.close);
      final service = NoteService(NoteDao(database), database);

      final first = await service.ensureTag('  想法 ');
      // 同名再来一次不能撞 UNIQUE 约束，应该拿回同一条。
      final second = await service.ensureTag('想法');

      expect(first.name, '想法');
      expect(second.id, first.id);
      expect(await database.select(database.tags).get(), hasLength(1));
    });

    test('rejects blank and over-long names before touching the database',
        () async {
      final database = AppDatabase.connect(NativeDatabase.memory());
      addTearDown(database.close);
      final service = NoteService(NoteDao(database), database);

      await expectLater(service.ensureTag('   '), throwsArgumentError);
      await expectLater(
        service.ensureTag('a' * (NoteService.maxTagNameLength + 1)),
        throwsArgumentError,
      );
      expect(await database.select(database.tags).get(), isEmpty);
    });
  });

  test('deleteTag detaches the tag from every note', () async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = NoteService(NoteDao(database), database);

    await service.importNotes([
      ImportedNote(content: 'one', tags: ['keep', 'drop']),
      ImportedNote(content: 'two', tags: ['drop']),
    ]);
    final drop = (await service.getAllTags()).firstWhere((t) => t.name == 'drop');

    await service.deleteTag(drop.id);

    expect((await service.getAllTags()).map((t) => t.name), ['keep']);
    final notes = await database.select(database.notes).get();
    expect(notes, hasLength(2));
    final links = await database.select(database.noteTags).get();
    expect(links.every((link) => link.tagId != drop.id), isTrue);
    expect(links, hasLength(1));
  });

  test('setTagsForNote keeps the old tags when a new one is invalid', () async {
    final database = AppDatabase.connect(NativeDatabase.memory());
    addTearDown(database.close);
    final service = NoteService(NoteDao(database), database);

    await service.importNotes([
      ImportedNote(content: 'one', tags: ['keep']),
    ]);
    final note = (await database.select(database.notes).get()).single;
    final keep = (await service.getAllTags()).single;

    // 第一个 id 不存在，外键会拒绝。没有事务的话此时旧标签已经删掉、新的
    // 一个都没插进去，笔记就变成没有标签；有事务则回滚到 keep。
    await expectLater(
      service.setTagsForNote(note.id, [9999, keep.id]),
      throwsA(anything),
    );

    final tags = await service.getTagsForNote(note.id);
    expect(tags.map((t) => t.name), ['keep']);
  });
}
