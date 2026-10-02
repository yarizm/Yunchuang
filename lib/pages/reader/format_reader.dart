import 'package:flutter/material.dart';

enum ReadingMode { scroll, page }

/// 三种正文阅读器的共同基类。
///
/// 阅读位置不从这里取：滚动模式由 `ReaderScrollController` 按字符换算，
/// 翻页模式由 `PagedReader.onPositionChanged` 回报，都是字符比例。
abstract class FormatReader extends StatefulWidget {
  const FormatReader({super.key});

  bool get supportsSelection;
  bool get supportsPagedMode;
}
