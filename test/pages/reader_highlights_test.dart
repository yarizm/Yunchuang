import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/models/tts_highlight.dart';
import 'package:yunchuang/pages/reader/reader_highlights.dart';

void main() {
  const red = Color(0xFFFF0000);
  const blue = Color(0xFF0000FF);

  List<(String, Color?)> pieces(List<InlineSpan> spans) => [
        for (final span in spans.cast<TextSpan>())
          (span.text!, span.style?.backgroundColor),
      ];

  test('later layers cover earlier ones', () {
    final spans = applyHighlightLayers(
      const [TextSpan(text: 'abcdefgh')],
      10,
      const [
        (start: 11, end: 17, color: red),
        (start: 13, end: 15, color: blue),
      ],
    );

    expect(pieces(spans), [
      ('a', null),
      ('bc', red),
      ('de', blue),
      ('fg', red),
      ('h', null),
    ]);
  });

  test('keeps span styles and recognizers across cuts', () {
    final recognizer = TapGestureRecognizer();
    addTearDown(recognizer.dispose);
    const bold = TextStyle(fontWeight: FontWeight.bold);
    final spans = applyHighlightLayers(
      [
        const TextSpan(text: 'ab'),
        TextSpan(text: 'cd', style: bold, recognizer: recognizer),
      ],
      0,
      const [(start: 1, end: 3, color: red)],
    );

    final texts = spans.cast<TextSpan>().toList();
    expect(texts.map((span) => span.text), ['a', 'b', 'c', 'd']);
    expect(texts[2].style?.fontWeight, FontWeight.bold);
    expect(texts[2].style?.backgroundColor, red);
    expect(texts[2].recognizer, recognizer);
    expect(texts[3].style, bold);
    expect(texts[3].recognizer, recognizer);
  });

  test('spans outside every layer come back untouched', () {
    const original = [TextSpan(text: 'abc')];
    final spans = applyHighlightLayers(
      original,
      100,
      const [(start: 0, end: 50, color: red)],
    );
    expect(identical(spans, original), isTrue);
  });

  test('reader layers stack paragraph, sentence and locator', () {
    final layers = readerHighlightLayers(
      const ColorScheme.light(),
      tts: const TtsHighlight(0, 20, sentenceStart: 5, sentenceEnd: 10),
      locatorStart: 30,
      locatorEnd: 35,
    );

    expect(layers.map((layer) => (layer.start, layer.end)), [
      (0, 20),
      (5, 10),
      (30, 35),
    ]);
    expect(layers[0].color.a, lessThan(layers[1].color.a));
  });
}
