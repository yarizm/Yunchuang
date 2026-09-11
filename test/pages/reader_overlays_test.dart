import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/pages/reader/reader_overlays.dart';

void main() {
  group('ReaderOverlays reading context', () {
    test('extracts context around the current normalized reading position', () {
      final content = '${List.filled(800, '甲').join()}'
          'CURRENT-MARKER'
          '${List.filled(800, '乙').join()}';

      final excerpt = ReaderOverlays.surroundingTextAtPosition(
        content,
        0.5,
        maxChars: 240,
      );

      expect(excerpt, hasLength(240));
      expect(excerpt, contains('CURRENT-MARKER'));
    });

    test('keeps excerpts anchored to chapter boundaries', () {
      final content = '${List.filled(600, '开').join()}'
          '${List.filled(600, '末').join()}';

      final start = ReaderOverlays.surroundingTextAtPosition(
        content,
        0,
        maxChars: 200,
      );
      final end = ReaderOverlays.surroundingTextAtPosition(
        content,
        1,
        maxChars: 200,
      );

      expect(start, List.filled(200, '开').join());
      expect(end, List.filled(200, '末').join());
    });

    test('returns short content intact and ignores empty content', () {
      expect(
        ReaderOverlays.surroundingTextAtPosition('  短章节  ', 0.8),
        '短章节',
      );
      expect(ReaderOverlays.surroundingTextAtPosition('  ', 0.5), isNull);
      expect(
        ReaderOverlays.surroundingTextAtPosition('正文', 0.5, maxChars: 0),
        isNull,
      );
    });

    test('finds a normalized position for an AI source query', () {
      final content = '${List.filled(300, '前').join()}'
          '方源现身'
          '${List.filled(700, '后').join()}';

      final position = ReaderOverlays.positionForSearchQuery(
        content,
        '“方源”',
      );

      expect(position, closeTo(300 / content.length, 0.001));
      expect(
        ReaderOverlays.positionForSearchQuery(content, '不存在'),
        isNull,
      );
    });

    test('resolves AI explanation as a collapsed selected-text attachment', () {
      final draft = ReaderOverlays.resolveInitialDraft(
        selectedText: '方源收起笑意。',
      );

      expect(draft, isNotNull);
      expect(draft!.instruction, contains('解释这段选中文本'));
      expect(draft.attachments, hasLength(1));
      expect(draft.attachments.single.title, '选中文本');
      expect(draft.attachments.single.content, '方源收起笑意。');
      expect(draft.toModelContent(), contains('方源收起笑意。'));
      expect(ReaderOverlays.resolveInitialDraft(), isNull);
    });
  });
}
