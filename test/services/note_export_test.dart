import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/database/app_database.dart';
import 'package:yunchuang/database/daos/note_dao.dart';
import 'package:yunchuang/services/note_service.dart';

void main() {
  late AppDatabase database;
  late NoteService service;

  setUp(() {
    database = AppDatabase.connect(NativeDatabase.memory());
    service = NoteService(NoteDao(database), database);
  });

  tearDown(() async {
    await database.close();
  });

  group('buildExportRows', () {
    test('补上书名、章节名与标签', () async {
      final bookId = await _insertBook(database, '书甲');
      final chapterId = await _insertChapter(database, bookId, '第一章');
      final noteId = await service.createNote(
        bookId: bookId,
        chapterId: chapterId,
        selectedText: '原文',
        content: '想法',
      );
      final tagId = await service.createTag('灵感');
      await service.setTagsForNote(noteId, [tagId]);

      final rows = await service.buildExportRows(await service.getAllNotes());

      expect(rows, hasLength(1));
      expect(rows.single.bookTitle, '书甲');
      expect(rows.single.chapterTitle, '第一章');
      expect(rows.single.tags.single.name, '灵感');
    });

    test('没有章节的笔记不报错，章节名为空', () async {
      final bookId = await _insertBook(database, '书甲');
      await service.createNote(bookId: bookId, content: '随手记');

      final rows = await service.buildExportRows(await service.getAllNotes());

      expect(rows.single.chapterTitle, isNull);
      expect(rows.single.bookTitle, '书甲');
    });

    test('空列表直接返回空，不查库', () async {
      expect(await service.buildExportRows(const []), isEmpty);
    });
  });

  group('exportMarkdown', () {
    test('按书分组，标题下是该书的笔记', () async {
      final a = await _insertBook(database, '书甲');
      final b = await _insertBook(database, '书乙');
      await service.createNote(bookId: a, content: '甲的笔记');
      await service.createNote(bookId: b, content: '乙的笔记');

      final md = service.exportMarkdown(
        await service.buildExportRows(await service.getAllNotes()),
      );

      expect(md, contains('## 书甲'));
      expect(md, contains('## 书乙'));
      expect(md, contains('甲的笔记'));
      expect(md.indexOf('## 书甲'), lessThan(md.indexOf('甲的笔记')));
    });

    test('划线原文作为引用块，多行不塌成一行', () async {
      final bookId = await _insertBook(database, '书甲');
      await service.createNote(
        bookId: bookId,
        selectedText: '第一行\n第二行',
        content: '批注',
      );

      final md = service.exportMarkdown(
        await service.buildExportRows(await service.getAllNotes()),
      );

      expect(md, contains('> 第一行'));
      expect(md, contains('> 第二行'));
    });

    test('标签写成 # 形式', () async {
      final bookId = await _insertBook(database, '书甲');
      final noteId = await service.createNote(bookId: bookId, content: '正文');
      final tagId = await service.createTag('哲学');
      await service.setTagsForNote(noteId, [tagId]);

      final md = service.exportMarkdown(
        await service.buildExportRows(await service.getAllNotes()),
      );

      expect(md, contains('#哲学'));
    });

    test('没有笔记时给出说明而不是空文件', () {
      final md = service.exportMarkdown(const []);

      expect(md, contains('# 笔记'));
      expect(md, contains('_没有笔记_'));
    });
  });

  group('exportCsv', () {
    test('表头齐全，一条笔记一行', () async {
      final bookId = await _insertBook(database, '书甲');
      final chapterId = await _insertChapter(database, bookId, '第一章');
      final noteId = await service.createNote(
        bookId: bookId,
        chapterId: chapterId,
        selectedText: '原文',
        content: '想法',
      );
      final tagId = await service.createTag('灵感');
      await service.setTagsForNote(noteId, [tagId]);

      final csv = service.exportCsv(
        await service.buildExportRows(await service.getAllNotes()),
      );
      final lines = csv.split('\r\n').where((l) => l.isNotEmpty).toList();

      expect(lines.first, contains('书籍'));
      expect(lines.first, contains('划线原文'));
      expect(lines, hasLength(2));
      expect(lines[1], contains('书甲'));
      expect(lines[1], contains('第一章'));
      expect(lines[1], contains('灵感'));
    });

    // 逗号和引号是 CSV 的两个必炸点，交给转换器处理，这里盯住它确实处理了。
    test('正文里的逗号和引号被正确转义', () async {
      final bookId = await _insertBook(database, '书甲');
      await service.createNote(
        bookId: bookId,
        content: '他说，"这不对"，然后走了',
      );

      final csv = service.exportCsv(
        await service.buildExportRows(await service.getAllNotes()),
      );

      // 含逗号的字段必须被引号包起来，内部引号翻倍。
      expect(csv, contains('""这不对""'));
      final lines = csv.split('\r\n').where((l) => l.isNotEmpty).toList();
      expect(lines, hasLength(2), reason: '逗号不应把一条笔记拆成多行');
    });

    test('类型列用中文名', () async {
      final bookId = await _insertBook(database, '书甲');
      await database.into(database.notes).insert(
            NotesCompanion.insert(
              bookId: bookId,
              content: const Value('书签一条'),
              type: const Value('bookmark'),
            ),
          );

      final csv = service.exportCsv(
        await service.buildExportRows(await service.getAllNotes()),
      );

      expect(csv, contains('书签'));
    });
  });
}

Future<int> _insertBook(AppDatabase db, String title) {
  return db.into(db.books).insert(
        BooksCompanion.insert(
          title: title,
          filePath: '$title.txt',
          format: 'txt',
          fileSize: 1,
        ),
      );
}

Future<int> _insertChapter(AppDatabase db, int bookId, String title) {
  return db.into(db.chapters).insert(
        ChaptersCompanion.insert(
          bookId: bookId,
          title: title,
          contentIndex: 0,
          sortOrder: 0,
        ),
      );
}
