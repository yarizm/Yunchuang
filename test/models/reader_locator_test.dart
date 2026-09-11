import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/models/reader_locator.dart';

void main() {
  test('uses verified text offsets before other anchors', () {
    const content = '序章内容，方源第一次出现，后续内容。';
    final start = content.indexOf('方源');
    final locator = ReaderLocator(
      bookId: 1,
      chapterId: 2,
      textOffsetStart: start,
      textOffsetEnd: start + 2,
      selectedText: '方源',
      chapterPosition: 0.9,
    );

    final resolution = locator.resolveIn(content);

    expect(resolution?.textOffsetStart, start);
    expect(resolution?.textOffsetEnd, start + 2);
    expect(resolution?.position, closeTo(start / content.length, 0.000001));
  });

  test('recovers stale offsets using context around repeated text', () {
    const content = '旧线索：方源离开。新线索：方源返回。';
    final targetStart = content.lastIndexOf('方源');
    final anchor = ReaderLocator.textAnchorJson(
      content,
      targetStart,
      targetStart + 2,
    );
    final locator = ReaderLocator(
      bookId: 1,
      chapterId: 2,
      textOffsetStart: 0,
      textOffsetEnd: 2,
      selectedText: anchor['selectedText'] as String,
      contextBefore: anchor['contextBefore'] as String?,
      contextAfter: anchor['contextAfter'] as String?,
      contextHash: anchor['contextHash'] as String?,
    );

    final resolution = locator.resolveIn(content);

    expect(resolution?.textOffsetStart, targetStart);
    expect(resolution?.textOffsetEnd, targetStart + 2);
  });

  test('normalizes malformed json and falls back to chapter position', () {
    final locator = ReaderLocator.fromJson({
      'bookId': '7',
      'chapterId': -2,
      'textOffsetStart': -1,
      'textOffsetEnd': 3,
      'pageNumber': -5,
      'chapterPosition': 4,
    });

    final resolution = locator.resolveIn('没有目标文本');

    expect(locator.bookId, 7);
    expect(locator.chapterId, isNull);
    expect(locator.textOffsetStart, isNull);
    expect(locator.pageNumber, isNull);
    expect(resolution?.position, 1);
    expect(resolution?.textOffsetStart, isNull);
  });

  test('serializes all stable locator fields', () {
    const locator = ReaderLocator(
      bookId: 4,
      chapterId: 8,
      format: 'epub',
      textOffsetStart: 10,
      textOffsetEnd: 12,
      pageNumber: 3,
      chapterPosition: 0.25,
      query: '方源',
      selectedText: '方源',
      contextBefore: '人物',
      contextAfter: '出现',
      contextHash: '1234abcd',
    );

    final restored = ReaderLocator.fromJson(locator.toJson());

    expect(restored.bookId, 4);
    expect(restored.chapterId, 8);
    expect(restored.format, 'epub');
    expect(restored.textOffsetStart, 10);
    expect(restored.textOffsetEnd, 12);
    expect(restored.pageNumber, 3);
    expect(restored.chapterPosition, 0.25);
    expect(restored.query, '方源');
    expect(restored.selectedText, '方源');
    expect(restored.contextHash, '1234abcd');
  });
}
