import 'package:flutter/material.dart';

import '../../models/tts_highlight.dart';

/// 正文上叠的一层底色，字符坐标是整章正文的。
typedef TextHighlightLayer = ({int start, int end, Color color});

/// 阅读器正文的几层底色，后面的盖住前面的：听书正在读的段落、其中正在
/// 读的句子、定位跳转的目标。三种阅读器共用，颜色只在这里定。
List<TextHighlightLayer> readerHighlightLayers(
  ColorScheme colors, {
  TtsHighlight? tts,
  int? locatorStart,
  int? locatorEnd,
}) {
  final sentenceStart = tts?.sentenceStart;
  final sentenceEnd = tts?.sentenceEnd;
  return [
    if (tts != null)
      (
        start: tts.start,
        end: tts.end,
        color: colors.primary.withValues(alpha: 0.12),
      ),
    if (sentenceStart != null && sentenceEnd != null)
      (
        start: sentenceStart,
        end: sentenceEnd,
        color: colors.primary.withValues(alpha: 0.24),
      ),
    if (locatorStart != null && locatorEnd != null)
      (
        start: locatorStart,
        end: locatorEnd,
        color: colors.primary.withValues(alpha: 0.22),
      ),
  ];
}

/// 把从全文偏移 [start] 开始的一串 [spans] 按 [layers] 切开、染上底色。
///
/// [spans] 必须是平铺的 [TextSpan]（不带 children），阅读器的正文块都是
/// 这样拼的。原有的样式和点击识别器保留，只覆盖底色。
List<InlineSpan> applyHighlightLayers(
  List<InlineSpan> spans,
  int start,
  List<TextHighlightLayer> layers,
) {
  if (layers.isEmpty) return spans;
  var length = 0;
  for (final span in spans) {
    if (span is TextSpan) length += span.text?.length ?? 0;
  }
  final end = start + length;
  final relevant = [
    for (final layer in layers)
      if (layer.start < layer.end && layer.start < end && layer.end > start)
        layer,
  ];
  if (relevant.isEmpty) return spans;

  final cuts = <int>{start, end};
  for (final layer in relevant) {
    cuts
      ..add(layer.start.clamp(start, end).toInt())
      ..add(layer.end.clamp(start, end).toInt());
  }
  final sortedCuts = cuts.toList()..sort();

  Color? colorAt(int offset) {
    Color? color;
    for (final layer in relevant) {
      if (layer.start <= offset && offset < layer.end) color = layer.color;
    }
    return color;
  }

  final result = <InlineSpan>[];
  var spanStart = start;
  var cutIndex = 0;
  for (final span in spans) {
    final text = span is TextSpan ? span.text ?? '' : '';
    if (span is! TextSpan || text.isEmpty) {
      result.add(span);
      continue;
    }
    final spanEnd = spanStart + text.length;
    var cursor = spanStart;
    while (cursor < spanEnd) {
      while (sortedCuts[cutIndex] <= cursor) {
        cutIndex++;
      }
      final next =
          sortedCuts[cutIndex] < spanEnd ? sortedCuts[cutIndex] : spanEnd;
      final color = colorAt(cursor);
      if (color == null && cursor == spanStart && next == spanEnd) {
        result.add(span);
      } else {
        result.add(
          TextSpan(
            text: text.substring(cursor - spanStart, next - spanStart),
            style: color == null
                ? span.style
                : (span.style ?? const TextStyle())
                    .copyWith(backgroundColor: color),
            recognizer: span.recognizer,
          ),
        );
      }
      cursor = next;
    }
    spanStart = spanEnd;
  }
  return result;
}
