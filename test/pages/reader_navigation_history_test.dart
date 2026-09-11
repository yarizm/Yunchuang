import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/models/reader_locator.dart';
import 'package:yunchuang/pages/reader/reader_navigation_history.dart';

ReaderLocator _location(int chapterId, double position) {
  return ReaderLocator(
    bookId: 1,
    chapterId: chapterId,
    chapterPosition: position,
  );
}

void main() {
  test('walks backward and forward through recorded jumps', () {
    final history = ReaderNavigationHistory();
    final first = _location(1, 0.2);
    final second = _location(3, 0.4);
    final third = _location(5, 0.6);

    history.recordJump(current: first, target: second);
    history.recordJump(current: second, target: third);

    expect(history.goBack(third)?.chapterId, 3);
    expect(history.goBack(second)?.chapterId, 1);
    expect(history.goForward(first)?.chapterId, 3);
    expect(history.goForward(second)?.chapterId, 5);
  });

  test('a new jump after going back clears forward history', () {
    final history = ReaderNavigationHistory();
    final first = _location(1, 0.1);
    final second = _location(2, 0.2);
    final third = _location(3, 0.3);

    history.recordJump(current: first, target: second);
    history.recordJump(current: second, target: third);
    expect(history.goBack(third), second);
    expect(history.canGoForward, isTrue);

    history.recordJump(current: second, target: _location(4, 0.4));

    expect(history.canGoForward, isFalse);
  });

  test('deduplicates nearby positions and enforces the size limit', () {
    final history = ReaderNavigationHistory(maxEntries: 2);

    expect(
      history.recordJump(
        current: _location(1, 0.2),
        target: _location(1, 0.2005),
      ),
      isFalse,
    );
    history.recordJump(
      current: _location(1, 0.2),
      target: _location(2, 0.2),
    );
    history.recordJump(
      current: _location(2, 0.2),
      target: _location(3, 0.2),
    );
    history.recordJump(
      current: _location(3, 0.2),
      target: _location(4, 0.2),
    );

    expect(history.backCount, 2);
    expect(history.goBack(_location(4, 0.2))?.chapterId, 3);
    expect(history.goBack(_location(3, 0.2))?.chapterId, 2);
  });

  test('can seed the saved reading position for an external entry', () {
    final history = ReaderNavigationHistory();
    history.seedBackLocation(_location(8, 0.75));

    final restored = history.goBack(_location(2, 0.1));

    expect(restored?.chapterId, 8);
    expect(restored?.chapterPosition, 0.75);
  });
}
