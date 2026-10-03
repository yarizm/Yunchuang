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

  group('parseMetadata', () {
    ({String title, String author}) parse(String text) {
      final meta = TxtParser.parseMetadata(text, fallbackTitle: '文件名');
      return (title: meta.title, author: meta.author);
    }

    test('strips the label from an author line', () {
      expect(
        parse('测试长篇\n\n作者：手测样书\n\n第一章 雨巷\n正文。'),
        (title: '测试长篇', author: '手测样书'),
      );
      expect(parse('书名\n作者: 某人\n第一章 开始').author, '某人');
      expect(parse('书名\n作 者：某人\n第一章 开始').author, '某人');
      expect(parse('书名\n文/某人\n第一章 开始').author, '某人');
      // 作者行前面隔着别的信息也能找到。
      expect(parse('书名\n类型：玄幻\n作者：乙\n第一章 开始').author, '乙');
    });

    test('leaves the author empty when nothing looks like one', () {
      // 第二行就是章节标题：不能当作者。
      expect(parse('我的书名\n第一章 开始\n正文。'), (title: '我的书名', author: ''));
      // 第二行是正文。
      expect(parse('我的书名\n他推开门，屋里没有人。\n').author, '');
      // 别的「键：值」信息、栏目名不是作者。
      expect(parse('我的书名\n类型：玄幻\n第一章 开始').author, '');
      expect(parse('我的书名\n内容简介\n一段简介。').author, '');
    });

    test('skips separators and book title marks for the title', () {
      expect(
        parse('------------\n《真正的书名》\n作者：甲\n第一章 开始'),
        (title: '真正的书名', author: '甲'),
      );
      expect(parse('书名：三体\n作者：刘慈欣').title, '三体');
      // 「三部曲」里的「三部」不能被当成卷标题截断。
      expect(parse('三部曲\n作者：某人\n第一章 开始').title, '三部曲');
    });

    test('falls back to the file name when the text opens with a chapter', () {
      expect(parse('第一章 开始\n正文。'), (title: '文件名', author: ''));
      expect(parse('楔子\n正文。').title, '文件名');
      expect(parse('').title, '文件名');
      expect(parse('他推开门，屋里没有人。\n第一章 开始').title, '文件名');
    });

    test('reads an English "by" line after the title', () {
      expect(
        parse('The Time Machine\nby H. G. Wells\n\nChapter 1\nText.'),
        (title: 'The Time Machine', author: 'H. G. Wells'),
      );
    });
  });
}
