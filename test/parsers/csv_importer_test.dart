import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/parsers/csv_importer.dart';

void main() {
  group('CsvImporter', () {
    test('parses standard CSV with headers', () {
      const csv = 'selectedText,content,tags\n'
          '高亮文本,笔记内容,"标签1,标签2"\n'
          '另一条高亮,另一条笔记,标签3';
      final notes = CsvImporter.parse(csv);
      expect(notes.length, 2);
      expect(notes[0].selectedText, '高亮文本');
      expect(notes[0].content, '笔记内容');
      expect(notes[0].tags, ['标签1', '标签2']);
      expect(notes[1].selectedText, '另一条高亮');
      expect(notes[1].content, '另一条笔记');
      expect(notes[1].tags, ['标签3']);
    });

    test('handles escaped quotes in CSV', () {
      const csv = 'selectedText,content\n'
          '"含""引号""的文本","普通笔记"';
      final notes = CsvImporter.parse(csv);
      expect(notes.length, 1);
      expect(notes[0].selectedText, '含"引号"的文本');
      expect(notes[0].content, '普通笔记');
    });

    test('handles empty CSV', () {
      final notes = CsvImporter.parse('');
      expect(notes, isEmpty);
    });

    test('handles CSV with missing columns', () {
      const csv = 'selectedText\n'
          'just text';
      final notes = CsvImporter.parse(csv);
      expect(notes.length, 1);
      expect(notes[0].selectedText, 'just text');
      expect(notes[0].content, isNull);
      expect(notes[0].tags, isEmpty);
    });

    test('handles quoted fields with commas', () {
      const csv = 'selectedText,content,tags\n'
          '"text, with comma","content","tag1,tag2"';
      final notes = CsvImporter.parse(csv);
      expect(notes.length, 1);
      expect(notes[0].selectedText, 'text, with comma');
      expect(notes[0].content, 'content');
      expect(notes[0].tags, ['tag1', 'tag2']);
    });
  });

  group('ImportedNote', () {
    test('has sensible defaults', () {
      final note = ImportedNote();
      expect(note.selectedText, isNull);
      expect(note.content, isNull);
      expect(note.tags, isEmpty);
    });

    test('stores provided values', () {
      final note = ImportedNote(
        selectedText: 'highlight',
        content: 'note',
        tags: ['a', 'b'],
      );
      expect(note.selectedText, 'highlight');
      expect(note.content, 'note');
      expect(note.tags, ['a', 'b']);
    });
  });
}
