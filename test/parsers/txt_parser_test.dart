import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/parsers/txt_parser.dart';

void main() {
  group('TxtParser', () {
    test('splits text into chapters by chapter pattern', () {
      const text = '''
第一章 开始
这是第一章的内容。

第二章 继续
这是第二章的内容。

第三章 结束
这是第三章的内容。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.length, 3);
      expect(chapters[0].title, '第一章 开始');
      expect(chapters[1].title, '第二章 继续');
      expect(chapters[2].title, '第三章 结束');
    });

    test('falls back to single chapter for plain text', () {
      const text = 'This is just a plain text without chapter markers.';
      final chapters = TxtParser.parseChapters(text);
      expect(chapters.length, 1);
      expect(chapters[0].title, '全文');
    });

    test('splits text into chapters by 回 pattern', () {
      const text = '''
第十回 开篇
这是第十回的内容。

第十一回 发展
这是第十一回的内容。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.length, 2);
      expect(chapters[0].title, '第十回 开篇');
      expect(chapters[1].title, '第十一回 发展');
    });

    test('splits text into chapters by 篇 pattern', () {
      const text = '''
第一篇 序
这是第一篇的内容。

第二篇 高潮
这是第二篇的内容。

第三篇 结局
这是第三篇的内容。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.length, 3);
      expect(chapters[0].title, '第一篇 序');
      expect(chapters[1].title, '第二篇 高潮');
      expect(chapters[2].title, '第三篇 结局');
    });

    test('splits text into chapters by English Chapter pattern', () {
      const text = '''
Chapter 1 Introduction

This is the first chapter.

Chapter 2 Development

This is the second chapter.
''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.length, 2);
      expect(chapters[0].title, 'Chapter 1 Introduction');
      expect(chapters[1].title, 'Chapter 2 Development');
    });

    test('prefers chapter headings over lower-level section headings', () {
      const text = '''
第一章 开始
这是第一章的内容。

第一节 背景
这是第一节的内容。

第二节 细节
这是第二节的内容。

第二章 结束
这是第二章的内容。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.length, 2);
      expect(chapters[0].title, '第一章 开始');
      expect(chapters[1].title, '第二章 结束');
    });

    test('uses section headings when they are the main structure', () {
      const text = '''
第一节 起点
这里是第一节。

第二节 展开
这里是第二节。

第三节 收束
这里是第三节。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.length, 3);
      expect(chapters[0].title, '第一节 起点');
      expect(chapters[2].title, '第三节 收束');
    });

    test('treats volumes as structure instead of chapters', () {
      const text = '''
第一卷 起点

第一章 开始
这是第一章。

第二章 继续
这是第二章。

第二卷 新旅程

第三章 变化
这是第三章。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '第一章 开始',
        '第二章 继续',
        '第三章 变化',
      ]);
      expect(chapters[1].content, contains('第二卷 新旅程'));
    });

    test('supports 话 headings and titles ending with punctuation', () {
      const text = '''
第一话 在睡梦中死去
内容一。

第二话 人物属性是定制的吗？
内容二。

第3话 再出发
内容三。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.length, 3);
      expect(chapters[1].title, '第二话 人物属性是定制的吗？');
    });

    test('supports headings without 第 and number-title concatenation', () {
      const text = '''
十三话 艳丽的蘑菇
内容十三。

14话，新的旅程
内容十四。

15没有章或节
内容十五。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '十三话 艳丽的蘑菇',
        '14话，新的旅程',
        '15没有章或节',
      ]);
    });

    test('ignores repeated chapter end markers', () {
      const text = '''
第一话 开始
内容一。
第一话 完

第二话 继续
内容二。
第二话 终わり

第三话 结束
内容三。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '第一话 开始',
        '第二话 继续',
        '第三话 结束',
      ]);
    });

    test('does not let loose chapter mentions override regular sections', () {
      const text = '''
第一卷：开始

第一节：真正的第一节
正文。

第二节：真正的第二节
正文。

第三节：真正的第三节
正文。

百节林地。

243章内容，修改成245章内容。

1.作者说明
2.更新计划''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '第一节：真正的第一节',
        '第二节：真正的第二节',
        '第三节：真正的第三节',
      ]);
    });

    test('combines explicit and bare numeric chapter headings', () {
      const text = '''
第一话 开始
内容一。

2 第二段
内容二。

3
只有数字的标题也应识别。

第四话 结束
内容四。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '第一话 开始',
        '2 第二段',
        '3',
        '第四话 结束',
      ]);
    });

    test('uses bare numeric headings as the main structure', () {
      const text = '''
1
第一段。

2、继续
第二段。

3 结束
第三段。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.length, 3);
      expect(chapters.last.title, '3 结束');
    });

    test('keeps special headings alongside chapters', () {
      const text = '''
序章
这是序章。

第一章 开始
这是第一章。

第二章 继续
这是第二章。

尾声
这是尾声。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.length, 4);
      expect(chapters.first.title, '序章');
      expect(chapters.last.title, '尾声');
    });

    test('extracts title and author from first two non-empty lines', () {
      const text = '我的书名\n作者名\n\n第一章\n内容';
      final meta = TxtParser.parseMetadata(text);
      expect(meta.title, '我的书名');
      expect(meta.author, '作者名');
    });
  });
}
