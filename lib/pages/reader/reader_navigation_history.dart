import '../../models/reader_locator.dart';

class ReaderNavigationHistory {
  final int maxEntries;
  final List<ReaderLocator> _back = [];
  final List<ReaderLocator> _forward = [];

  ReaderNavigationHistory({this.maxEntries = 50}) : assert(maxEntries > 0);

  bool get canGoBack => _back.isNotEmpty;
  bool get canGoForward => _forward.isNotEmpty;
  int get backCount => _back.length;
  int get forwardCount => _forward.length;

  void seedBackLocation(ReaderLocator locator) {
    if (_back.isNotEmpty && _sameLocation(_back.last, locator)) return;
    _pushBounded(_back, locator);
  }

  bool recordJump({
    required ReaderLocator current,
    required ReaderLocator target,
  }) {
    if (_sameLocation(current, target)) return false;
    if (_back.isEmpty || !_sameLocation(_back.last, current)) {
      _pushBounded(_back, current);
    }
    _forward.clear();
    return true;
  }

  ReaderLocator? goBack(ReaderLocator current) {
    if (_back.isEmpty) return null;
    final target = _back.removeLast();
    if (!_sameLocation(current, target)) {
      if (_forward.isEmpty || !_sameLocation(_forward.last, current)) {
        _pushBounded(_forward, current);
      }
    }
    return target;
  }

  ReaderLocator? goForward(ReaderLocator current) {
    if (_forward.isEmpty) return null;
    final target = _forward.removeLast();
    if (!_sameLocation(current, target)) {
      if (_back.isEmpty || !_sameLocation(_back.last, current)) {
        _pushBounded(_back, current);
      }
    }
    return target;
  }

  void _pushBounded(List<ReaderLocator> stack, ReaderLocator locator) {
    stack.add(locator);
    if (stack.length > maxEntries) {
      stack.removeRange(0, stack.length - maxEntries);
    }
  }

  bool _sameLocation(ReaderLocator left, ReaderLocator right) {
    if (left.bookId != right.bookId ||
        left.chapterId != right.chapterId ||
        left.pageNumber != right.pageNumber) {
      return false;
    }

    final leftOffset = left.textOffsetStart;
    final rightOffset = right.textOffsetStart;
    if (leftOffset != null && rightOffset != null) {
      return (leftOffset - rightOffset).abs() <= 1;
    }

    final leftPosition = left.chapterPosition;
    final rightPosition = right.chapterPosition;
    if (leftPosition != null && rightPosition != null) {
      return (leftPosition - rightPosition).abs() <= 0.001;
    }

    return left.query == right.query &&
        left.selectedText == right.selectedText &&
        leftOffset == rightOffset;
  }
}
