import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/providers/ai/agent_models.dart';
import 'package:yunchuang/widgets/ai_chat/agent_source_parsing.dart';

AgentEvent statusEvent(String tool, Object? result) {
  return AgentEvent.status('', {'tool': tool, 'result': result});
}

void main() {
  group('toolEventsFromMetadata', () {
    test('取出记录下来的工具调用', () {
      final json = jsonEncode({
        'toolEvents': ['搜索正文', '读取章节'],
      });
      expect(toolEventsFromMetadata(json), ['搜索正文', '读取章节']);
    });

    // metadataJson 是历史消息里存下来的自由格式字段，可能是旧版本写的、
    // 也可能被改坏。解析不了要当没有，不能让整个对话打不开。
    test('空值、坏 JSON、类型不对都退回空表', () {
      expect(toolEventsFromMetadata(null), isEmpty);
      expect(toolEventsFromMetadata(''), isEmpty);
      expect(toolEventsFromMetadata('{ 不是 json'), isEmpty);
      expect(toolEventsFromMetadata('[1,2,3]'), isEmpty);
      expect(toolEventsFromMetadata('{"toolEvents":"不是数组"}'), isEmpty);
      expect(toolEventsFromMetadata('{}'), isEmpty);
    });

    test('非字符串元素按字符串取', () {
      expect(toolEventsFromMetadata('{"toolEvents":[1,true]}'), ['1', 'true']);
    });
  });

  group('sourceReferencesFromStatus', () {
    test('认不出的工具名不产出引用', () {
      expect(sourceReferencesFromStatus(statusEvent('unknown_tool', {})),
          isEmpty);
    });

    test('metadata 缺失或 result 不是 Map 时不产出引用', () {
      expect(sourceReferencesFromStatus(const AgentEvent.status('')), isEmpty);
      expect(sourceReferencesFromStatus(statusEvent('search_notes', '字符串')),
          isEmpty);
      expect(sourceReferencesFromStatus(statusEvent('search_notes', null)),
          isEmpty);
    });

    test('正文搜索结果转成章节引用', () {
      final refs = sourceReferencesFromStatus(statusEvent('search_current_book', {
        'bookId': 7,
        'query': '流水线',
        'matches': [
          {
            'chapterId': 12,
            'chapterTitle': '第三章',
            'hitCount': 3,
            'snippets': ['讲了流水线技术', '又提到流水线'],
            'textOffsetStart': 100,
            'textOffsetEnd': 110,
            'chapterPosition': 0.4,
          },
        ],
      }));

      expect(refs, hasLength(1));
      final ref = refs.single;
      expect(ref.type, 'chapter');
      expect(ref.title, '第三章');
      expect(ref.subtitle, '正文 · 命中 3 次');
      expect(ref.snippet, '讲了流水线技术 又提到流水线');
      expect(ref.locator?.bookId, 7);
      expect(ref.locator?.chapterId, 12);
      expect(ref.locator?.query, '流水线');
    });

    test('未读命中会在副标题里标出来', () {
      final refs = sourceReferencesFromStatus(statusEvent('search_current_book', {
        'bookId': 1,
        'matches': [
          {
            'chapterTitle': '后面的章',
            'isUnread': true,
            'snippets': ['剧透内容'],
          },
        ],
      }));
      expect(refs.single.subtitle, startsWith('未读正文'));
    });

    test('片段全是空白的命中被丢掉', () {
      final refs = sourceReferencesFromStatus(statusEvent('search_current_book', {
        'bookId': 1,
        'matches': [
          {'chapterTitle': '空', 'snippets': ['   ', '\n']},
        ],
      }));
      expect(refs, isEmpty);
    });

    // 工具没回 bookId 时用面板知道的那本书兜底，否则跳转定位器建不出来。
    test('章节片段缺 bookId 时用兜底值', () {
      final data = {'excerpt': '一段正文', 'chapterId': 5};
      expect(
        sourceReferencesFromStatus(
          statusEvent('read_chapter_excerpt', data),
        ).single.locator,
        isNull,
      );
      expect(
        sourceReferencesFromStatus(
          statusEvent('read_chapter_excerpt', data),
          fallbackBookId: 42,
        ).single.locator?.bookId,
        42,
      );
    });

    test('关键词没命中时片段副标题会说明', () {
      final refs = sourceReferencesFromStatus(
        statusEvent('read_chapter_excerpt', {
          'excerpt': '一段正文',
          'queryMatched': false,
        }),
      );
      expect(refs.single.subtitle, '章节片段 · 关键词未命中');
    });

    test('笔记搜索按类型给出中文标签', () {
      List<AiSourceReference> refsFor(String? type) =>
          sourceReferencesFromStatus(statusEvent('search_notes', {
            'bookId': 3,
            'matches': [
              {'noteId': 9, 'type': type, 'selectedText': '划下的句子'},
            ],
          }));

      expect(refsFor('highlight').single.subtitle, '划线');
      expect(refsFor('bookmark').single.subtitle, '书签');
      expect(refsFor(null).single.subtitle, '笔记');
    });

    test('笔记没有 snippets 时退回正文字段', () {
      final refs = sourceReferencesFromStatus(statusEvent('search_notes', {
        'bookId': 3,
        'matches': [
          {'noteId': 1, 'content': '笔记正文'},
        ],
      }));
      expect(refs.single.snippet, '笔记正文');
    });
  });

  group('数字字段的容错', () {
    // 这些值由模型或工具序列化而来，同一个字段有时是 int、有时是字符串、
    // 有时干脆缺失。任何一种都不该让整条引用作废。
    test('chapterId 是字符串数字时也能读出来', () {
      final refs = sourceReferencesFromStatus(statusEvent('search_current_book', {
        'bookId': '7',
        'matches': [
          {'chapterId': '12', 'snippets': ['命中'], 'chapterTitle': '章'},
        ],
      }));
      expect(refs.single.locator?.bookId, 7);
      expect(refs.single.locator?.chapterId, 12);
    });

    test('chapterPosition 越界会被夹回 0..1，非法值当没有', () {
      Object? positionFor(Object? raw) => sourceReferencesFromStatus(
            statusEvent('read_chapter_excerpt', {
              'bookId': 1,
              'excerpt': '正文',
              'chapterPosition': raw,
            }),
          ).single.chapterPosition;

      expect(positionFor(1.7), 1.0);
      expect(positionFor(-0.5), 0.0);
      expect(positionFor('0.25'), 0.25);
      expect(positionFor('说不清'), isNull);
      expect(positionFor(double.nan), isNull);
      expect(positionFor(double.infinity), isNull);
    });
  });

  group('compactSnippet', () {
    test('把换行和连续空白压成单个空格', () {
      expect(compactSnippet('  第一行\n\n  第二行\t结束 '), '第一行 第二行 结束');
    });

    test('超长截断并加省略号', () {
      final long = '字' * 400;
      final result = compactSnippet(long, maxChars: 10);
      expect(result, '${'字' * 10}...');
    });

    test('刚好等于上限时不截断', () {
      expect(compactSnippet('字' * 10, maxChars: 10), '字' * 10);
    });
  });

  group('sourceReferenceKey', () {
    test('同一段正文的两条引用得到相同的键', () {
      const a = AiSourceReference(
        type: 'chapter',
        title: '搜索来的',
        subtitle: '正文',
        chapterId: 5,
        snippet: '同一段话',
      );
      const b = AiSourceReference(
        type: 'chapter',
        title: '读片段来的',
        subtitle: '章节片段',
        chapterId: 5,
        snippet: '同一段话',
      );
      expect(sourceReferenceKey(a), sourceReferenceKey(b));
    });

    test('章节不同就是不同的键', () {
      const a = AiSourceReference(
        type: 'chapter',
        title: '甲',
        subtitle: '正文',
        chapterId: 5,
        snippet: '话',
      );
      const b = AiSourceReference(
        type: 'chapter',
        title: '甲',
        subtitle: '正文',
        chapterId: 6,
        snippet: '话',
      );
      expect(sourceReferenceKey(a), isNot(sourceReferenceKey(b)));
    });
  });
}