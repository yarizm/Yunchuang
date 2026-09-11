import 'package:flutter/material.dart';

class TextSelectionData {
  final String text;
  final int startOffset;
  final int endOffset;
  const TextSelectionData({
    required this.text,
    required this.startOffset,
    required this.endOffset,
  });
}

enum ReadingMode { scroll, page }

abstract class FormatReader extends StatefulWidget {
  const FormatReader({super.key});

  double get currentPosition;
  void jumpToPosition(double pos);
  Stream<TextSelectionData> get onSelection;
  void highlightSentence(int index);
  void clearHighlight();
  bool get supportsSelection;
  bool get supportsPagedMode;
}
