import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/services/chapter_relocation.dart';

void main() {
  // 旧规则切出来的章节：第一百四十三章被「1：0……」这一行劈成了两章。
  const intro = '正文一。众人在擂台下等着开赛。';
  const fakeTitle = '1：0，顺利斩杀这支叫做聚义轩的流派';
  const fakeBody = '众人一阵欢呼。明月点了点头，转身看向下一场的对手。';
  const next = '正文二。水云谣的曲子从远处传来，听得人心头一紧。';
  final oldChapters = [
    (title: '第一百四十三章 玉米地的爱恋', content: intro),
    (title: fakeTitle, content: fakeBody),
    (title: '第一百四十四章 水云谣', content: next),
  ];
  final newChapters = [
    (
      title: '第一百四十三章 玉米地的爱恋',
      content: '$intro\n$fakeTitle\n$fakeBody',
    ),
    (title: '第一百四十四章 水云谣', content: next),
  ];

  ChapterPosition? relocate(
    ChapterPosition position, {
    List<RelocatableChapter>? to,
  }) {
    return relocateChapterPositions(
      oldChapters: oldChapters,
      newChapters: to ?? newChapters,
      positions: [position],
    ).single;
  }

  test('moves a note out of a false chapter into the real one', () {
    final at = fakeBody.indexOf('明月');
    final moved = relocate(
      ChapterPosition(chapterIndex: 1, start: at, end: at + 2, text: '明月'),
    )!;

    expect(moved.chapterIndex, 0);
    expect(newChapters[0].content.substring(moved.start, moved.end), '明月');
  });

  test('keeps the offset inside a chapter that was split correctly', () {
    final at = next.indexOf('水云谣的曲子');
    final moved = relocate(
      ChapterPosition(chapterIndex: 2, start: at, end: at + 3, text: '水云谣'),
    )!;

    expect(moved.chapterIndex, 1);
    expect(moved.start, at);
    expect(moved.end, at + 3);
  });

  test('finds a reading position at the very end of a chapter', () {
    final moved = relocate(
      const ChapterPosition(
        chapterIndex: 1,
        start: fakeBody.length,
        approximate: true,
      ),
    )!;

    expect(moved.chapterIndex, 0);
    expect(moved.start, newChapters[0].content.length);
  });

  test('drops a note whose text is gone but keeps the reading position', () {
    final rewritten = [
      (title: '第一百四十三章 玉米地的爱恋', content: '改写过的正文。'),
      (title: '第一百四十四章 水云谣', content: '另一份改写过的正文。'),
    ];
    final results = relocateChapterPositions(
      oldChapters: oldChapters,
      newChapters: rewritten,
      positions: [
        const ChapterPosition(
          chapterIndex: 2,
          start: 5,
          end: 8,
          text: '水云谣',
        ),
        const ChapterPosition(chapterIndex: 2, start: 5, approximate: true),
      ],
    );

    expect(results[0], isNull);
    // 退到同名的那章开头。
    expect(results[1]!.chapterIndex, 1);
    expect(results[1]!.start, 0);
  });

  test('prefers the chapter with the same title for repeated text', () {
    const repeated = '他抬头看了看天，天色已经暗了下来。';
    final old = [
      (title: '第一章 开始', content: repeated),
      (title: '假章节', content: '一段被切出来的正文。'),
      (title: '第二章 结局', content: repeated),
    ];
    final fresh = [
      (title: '第一章 开始', content: '$repeated\n假章节\n一段被切出来的正文。'),
      (title: '第二章 结局', content: repeated),
    ];

    final moved = relocateChapterPositions(
      oldChapters: old,
      newChapters: fresh,
      positions: [const ChapterPosition(chapterIndex: 2, start: 2)],
    ).single!;

    expect(moved.chapterIndex, 1);
    expect(moved.start, 2);
  });

  test('keeps positions as they are when the chapters did not change', () {
    // PDF 的页：正文不缓存，章节就是页，换了文件也一样。
    final pages = [
      (title: '第 1 页', content: ''),
      (title: '第 2 页', content: ''),
    ];
    final moved = relocateChapterPositions(
      oldChapters: pages,
      newChapters: pages,
      positions: [const ChapterPosition(chapterIndex: 1, start: 7)],
    ).single!;

    expect(moved.chapterIndex, 1);
    expect(moved.start, 7);
  });
}
