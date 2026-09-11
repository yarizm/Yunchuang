import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/models/reader_locator.dart';
import 'package:yunchuang/providers/ai/agent_models.dart';

void main() {
  test('large attachments use compact persisted metadata and restore fully',
      () async {
    final content = List.generate(
      3000,
      (index) => '第 $index 段重复正文用于验证压缩存储。',
    ).join('\n');
    final draft = AiPromptDraft(
      instruction: '分析本章',
      attachments: [
        AiAttachment(
          id: 'chapter-1',
          title: '本章内容',
          content: content,
        ),
      ],
    );

    final persisted = await draft.toPersistedMetadataJson();
    final raw = jsonEncode(draft.toMetadataJson());
    final attachment =
        ((jsonDecode(persisted) as Map<String, dynamic>)['attachments'] as List)
            .single as Map<String, dynamic>;

    expect(attachment['content'], isNull);
    expect(attachment['contentEncoding'], 'gzip+base64');
    expect(attachment['contentLength'], content.length);
    expect(utf8.encode(persisted).length, lessThan(utf8.encode(raw).length));

    final restored = AiPromptDraft.attachmentsFromMetadata(persisted).single;
    expect(restored.summary, '本章内容 · 约 ${content.length} 字');
    expect(restored.content, content);
  });

  test('plain attachment metadata remains backward compatible', () {
    const content = '旧版本保存的正文附件';
    final metadata = jsonEncode({
      'attachments': [
        {
          'id': 'legacy',
          'title': '旧附件',
          'kind': 'text',
          'content': content,
        },
      ],
    });

    final restored = AiPromptDraft.attachmentsFromMetadata(metadata).single;

    expect(restored.length, content.length);
    expect(restored.content, content);
  });

  test('corrupt compressed attachment metadata does not break loading', () {
    final metadata = jsonEncode({
      'attachments': [
        {
          'id': 'broken',
          'title': '损坏附件',
          'kind': 'text',
          'contentEncoding': 'gzip+base64',
          'contentLength': 1234,
          'contentData': 'not-valid-base64',
        },
      ],
    });

    final restored = AiPromptDraft.attachmentsFromMetadata(metadata).single;

    expect(restored.summary, '损坏附件 · 约 1234 字');
    expect(restored.content, isEmpty);
    expect(restored.length, 0);
  });

  test('model length estimation does not decode compressed attachments', () {
    final metadata = jsonEncode({
      'attachments': [
        {
          'id': 'deferred',
          'title': '延迟附件',
          'kind': 'text',
          'contentEncoding': 'gzip+base64',
          'contentLength': 50000,
          'contentData': 'not-valid-base64',
        },
      ],
    });
    final attachment = AiPromptDraft.attachmentsFromMetadata(metadata).single;
    final draft = AiPromptDraft(
      instruction: '继续分析',
      attachments: [attachment],
    );

    expect(draft.modelContentLength, greaterThan(50000));
    expect(attachment.length, 50000);
  });

  test('source references preserve locators and load legacy positions', () {
    const reference = AiSourceReference(
      type: 'chapter',
      title: '第一章',
      snippet: '方源出现',
      bookId: 1,
      chapterId: 2,
      chapterPosition: 0.4,
      locator: ReaderLocator(
        bookId: 1,
        chapterId: 2,
        textOffsetStart: 16,
        textOffsetEnd: 18,
        selectedText: '方源',
      ),
    );

    final restored = AiSourceReference.fromJson(reference.toJson());
    final legacy = AiSourceReference.fromJson({
      'type': 'chapter',
      'title': '旧消息',
      'snippet': '旧引用',
      'bookId': 3,
      'chapterId': 4,
      'chapterPosition': 0.6,
      'query': '旧引用',
    });

    expect(restored.locator?.textOffsetStart, 16);
    expect(restored.locator?.selectedText, '方源');
    expect(legacy.locator, isNull);
    expect(legacy.bookId, 3);
    expect(legacy.chapterId, 4);
    expect(legacy.chapterPosition, 0.6);
  });
}
