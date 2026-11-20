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

    test('does not split on score and ranking lines in a 第X章 book', () {
      // 用户报告的书：网游竞技小说，正文里比分、名次以数字开头。
      const text = '''
第一百四十三章 玉米地的爱恋
正文一。
1：0，顺利斩杀这支叫做聚义轩的流派
众人一阵欢呼。
16强之后，估计就要强强碰撞了，这一场不好打。
明月点了点头。

第一百四十四章 水云谣
正文二。
1：0，先下一城！
对面的人脸色一沉。

第一百四十五章 血洗花间派
正文三。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '第一百四十三章 玉米地的爱恋',
        '第一百四十四章 水云谣',
        '第一百四十五章 血洗花间派',
      ]);
      expect(chapters[0].content, contains('1：0，顺利斩杀'));
      expect(chapters[0].content, contains('16强之后'));
      expect(chapters[1].content, contains('1：0，先下一城！'));
    });

    test('keeps a long 第X章 book whole when many lines start with numbers', () {
      // 之前裸数字行达到「第X章」的一成就整批当成标题。
      final buffer = StringBuffer();
      for (var number = 121; number <= 150; number++) {
        buffer.writeln('第$number章 标题$number');
        buffer.writeln('正文$number。');
        if (number % 3 == 0) {
          buffer.writeln('1：0，先下一城！');
          buffer.writeln('对面的人脸色一沉。');
          buffer.writeln('16强之后，估计就要强强碰撞了。');
          buffer.writeln('明月点了点头。');
          buffer.writeln('300金币就这么没了。');
          buffer.writeln('他叹了口气。');
        }
        buffer.writeln();
      }

      final chapters = TxtParser.parseChapters(buffer.toString());
      expect(chapters.length, 30);
      expect(chapters.first.title, '第121章 标题121');
      expect(chapters.last.title, '第150章 标题150');
      expect(chapters[2].content, contains('300金币就这么没了。'));
    });

    test('accepts bare numbers that continue large chinese chapter numbers', () {
      const text = '''
第一百零九章 甲
正文甲。

110 乙
正文乙。

第一百一十一章 丙
正文丙。

第两百章 丁
正文丁。

201、戊
正文戊。

第二〇二章 己
正文己。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '第一百零九章 甲',
        '110 乙',
        '第一百一十一章 丙',
        '第两百章 丁',
        '201、戊',
        '第二〇二章 己',
      ]);
    });

    test('ignores score and ranking lines in a bare-number book', () {
      const text = '''
1 开始
正文一。
1：0，先下一城！
对面的人脸色一沉。
16强之后，估计就要强强碰撞了。
明月点了点头。

2 继续
正文二。
300金币就这么没了。
他叹了口气。

3 结束
正文三。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '1 开始',
        '2 继续',
        '3 结束',
      ]);
      expect(chapters[0].content, contains('16强之后'));
      expect(chapters[1].content, contains('300金币'));
    });

    test('puts bare-number headings on the body, not the table of contents',
        () {
      const text = '''
目录
1 开始
2 继续
3 结束

1 开始
正文一。

2 继续
正文二。

3 结束
正文三。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '1 开始',
        '2 继续',
        '3 结束',
      ]);
      expect(chapters.map((chapter) => chapter.content), [
        '正文一。',
        '正文二。',
        '正文三。',
      ]);
    });

    test('lets bare-number headings restart after a volume heading', () {
      const text = '''
第一卷 春
1 开始
正文一。

2 继续
正文二。

第二卷 秋
1 重逢
正文三。

2 别离
正文四。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '1 开始',
        '2 继续',
        '1 重逢',
        '2 别离',
      ]);
    });

    test('keeps a bare-number book whose prose mentions 第X章', () {
      // 作者的话里提了两次「第X章」，这本书的标题仍然是数字。
      final body = '他沿着河岸往前走。' * 140;
      final buffer = StringBuffer();
      for (var number = 1; number <= 6; number++) {
        buffer.writeln('$number 标题$number');
        buffer.writeln(body);
        if (number == 2) buffer.writeln('第三章 我改了一个错字');
        if (number == 4) buffer.writeln('第五章 也改了');
        buffer.writeln();
      }

      final chapters = TxtParser.parseChapters(buffer.toString());
      expect(
        chapters.map((chapter) => chapter.title),
        [for (var number = 1; number <= 6; number++) '$number 标题$number'],
      );
      expect(chapters[1].content, contains('第三章 我改了一个错字'));
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

    test('splits extra chapters that carry a number or a subtitle', () {
      const text = '''
第一章 开始
正文一。

第二章 结局
正文二。

番外一 春日宴
番外正文一。

番外2：重逢
番外正文二。

番外篇·婚后
番外正文三。

【番外】雪夜
番外正文四。

番外（五）
番外正文五。

番外之一夜白头
番外正文六。

番外篇 第1章 归来
番外正文七。

番外
番外正文八。

外传 少年游
外传正文。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '第一章 开始',
        '第二章 结局',
        '番外一 春日宴',
        '番外2：重逢',
        '番外篇·婚后',
        '【番外】雪夜',
        '番外（五）',
        '番外之一夜白头',
        '番外篇 第1章 归来',
        '番外',
        '外传 少年游',
      ]);
      expect(chapters[1].content, '正文二。');
      expect(chapters[2].content, '番外正文一。');
      expect(chapters.last.content, '外传正文。');
    });

    test('does not split on prose lines that start with heading words', () {
      const text = '''
第一章 开始
番外一直没写完
番外两个人去了海边
番外之后还会有新书
番外，明天更新
番外篇什么时候出
外传来一阵喧哗声
番外：今天先写到这里。
前言不搭后语
尾声，大家都散了

第二章 结局
正文二。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '第一章 开始',
        '第二章 结局',
      ]);
      expect(chapters.first.content, contains('外传来一阵喧哗声'));
      expect(chapters.first.content, contains('番外：今天先写到这里。'));
      expect(chapters.first.content, contains('尾声，大家都散了'));
    });

    test('accepts a chapter marker glued to 番外 in a strong-heading book', () {
      const text = '''
第一章 开始
正文一。

第二章 结局
正文二。

第三章番外一
番外正文。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '第一章 开始',
        '第二章 结局',
        '第三章番外一',
      ]);
      expect(chapters[1].content, '正文二。');
    });

    test('keeps special headings that carry a subtitle', () {
      const text = '''
序章 风起
序章正文。

第一章 开始
正文一。

第二章 结局
正文二。

尾声：归来
尾声正文。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '序章 风起',
        '第一章 开始',
        '第二章 结局',
        '尾声：归来',
      ]);
      expect(chapters.first.content, '序章正文。');
      expect(chapters[2].content, '正文二。');
    });

    test('splits a file that only holds extra chapters', () {
      const text = '''
某某番外合集
作者：某人

番外一 春日宴
番外正文一。

番外二 冬雪
番外正文二。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '番外一 春日宴',
        '番外二 冬雪',
      ]);
      expect(chapters.last.content, '番外正文二。');
    });

    test('extracts title and author from first two non-empty lines', () {
      const text = '我的书名\n作者名\n\n第一章\n内容';
      final meta = TxtParser.parseMetadata(text);
      expect(meta.title, '我的书名');
      expect(meta.author, '作者名');
    });

    test('does not split on a sentence that starts with 第X章', () {
      const text = '''
第一章 初见
他推开门。

第三章的内容很精彩，让人停不下来。

第二章 再会
她笑了。

第三章 结局
天亮了。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '第一章 初见',
        '第二章 再会',
        '第三章 结局',
      ]);
      expect(chapters.first.content, contains('第三章的内容很精彩'));
      expect(chapters.every((chapter) => chapter.content.isNotEmpty), isTrue);
    });

    test('does not split when a weak heading book mentions 第X章 in prose', () {
      const text = '''
第一章开始
正文一。

第二章里，作者写了很多细节。

第二章继续
正文二。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '第一章开始',
        '第二章继续',
      ]);
      expect(chapters.first.content, contains('第二章里，作者写了很多细节'));
    });

    test('accepts weak headings split into 上/中/下 parts', () {
      const text = '''
第一章上
正文一。

第一章中
正文二。

第一章下
正文三。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '第一章上',
        '第一章中',
        '第一章下',
      ]);
    });

    test('does not split on a 完 that ends an ordinary verb', () {
      const text = '''
第一章 初见
他终于读完了第三章，合上书。

第二章 再会
她笑了。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '第一章 初见',
        '第二章 再会',
      ]);
      expect(chapters.first.content, contains('读完了第三章'));
    });

    test('drops table-of-contents headings that have no body', () {
      const text = '''
第一章 初见
第二章 再会
第三章 结局

第一章 初见
他推开门。

第二章 再会
她笑了。

第三章 结局
天亮了。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '第一章 初见',
        '第二章 再会',
        '第三章 结局',
      ]);
      expect(chapters.map((chapter) => chapter.content), [
        '他推开门。',
        '她笑了。',
        '天亮了。',
      ]);
    });

    test('keeps headings without body when the whole book has no body', () {
      const text = '第一章 初见\n第二章 再会\n第三章 结局';
      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), [
        '第一章 初见',
        '第二章 再会',
        '第三章 结局',
      ]);
      expect(chapters.every((chapter) => chapter.content.isEmpty), isTrue);
    });

    test('accepts headings that end with a lone full stop', () {
      const text = '''
第一章。
正文一。

第二章。
正文二。''';

      final chapters = TxtParser.parseChapters(text);
      expect(chapters.map((chapter) => chapter.title), ['第一章。', '第二章。']);
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

    test('falls back to the file name when the text opens with an extra', () {
      final metadata = TxtParser.parseMetadata(
        '番外一 春日宴\n番外正文。',
        fallbackTitle: '某某番外',
      );
      expect(metadata.title, '某某番外');
      expect(metadata.author, '');
    });

    test('reads an English "by" line after the title', () {
      expect(
        parse('The Time Machine\nby H. G. Wells\n\nChapter 1\nText.'),
        (title: 'The Time Machine', author: 'H. G. Wells'),
      );
    });
  });
}
