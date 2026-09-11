import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/html_text_document.dart';

/// Converts HTML into selectable spans whose plain text exactly matches
/// [parseHtmlTextDocument]. The owner must dispose recognizers added to
/// [recognizers].
List<InlineSpan> htmlToTextSpans(
  String html, {
  required double baseFontSize,
  double paragraphSpacing = 0,
  ValueChanged<HtmlTextLink>? onLinkTap,
  List<GestureRecognizer>? recognizers,
}) {
  final document = parseHtmlTextDocument(html);
  final linkRecognizers = <HtmlTextLink, TapGestureRecognizer>{};

  return [
    for (final segment in document.segments)
      TextSpan(
        text: segment.text,
        recognizer: segment.link == null || onLinkTap == null
            ? null
            : linkRecognizers.putIfAbsent(segment.link!, () {
                final recognizer = TapGestureRecognizer()
                  ..onTap = () => onLinkTap(segment.link!);
                recognizers?.add(recognizer);
                return recognizer;
              }),
        style: TextStyle(
          fontSize: _fontSizeForSegment(
            segment,
            baseFontSize,
            paragraphSpacing,
          ),
          fontWeight: segment.bold ? FontWeight.bold : null,
          fontStyle: segment.italic ? FontStyle.italic : null,
          decoration: segment.link == null ? null : TextDecoration.underline,
          decorationThickness: segment.link == null ? null : 1.2,
        ),
      ),
  ];
}

double _fontSizeForSegment(
  HtmlTextSegment segment,
  double baseFontSize,
  double paragraphSpacing,
) {
  final onlyBreaks =
      segment.text.isNotEmpty && segment.text.replaceAll('\n', '').isEmpty;
  if (onlyBreaks && paragraphSpacing > 0) {
    return baseFontSize + paragraphSpacing;
  }
  return baseFontSize * segment.fontScale;
}
