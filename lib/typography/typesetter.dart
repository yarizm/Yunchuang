import 'package:flutter/painting.dart';

import 'line_box.dart';
import 'paginator.dart';
import 'text_measurer.dart';

export 'line_box.dart';
export 'paginator.dart';
export 'text_measurer.dart';

/// 排版内核对外入口：把正文排成页盒序列。
///
/// 度量与分页是分开的两步——度量依赖 Flutter，分页不依赖。需要单独测试
/// 分页规则时直接调 [paginate]，不必经过这里。
class Typesetter {
  final TextMeasurer measurer;

  const Typesetter({this.measurer = const FlutterTextMeasurer()});

  List<PageBox> typeset({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required double pageHeight,
    required TextDirection direction,
    double? firstPageHeight,
    double paragraphSpacing = 0,
    StrutStyle? strutStyle,
  }) {
    final lines = measurer.layout(
      text: text,
      style: style,
      maxWidth: maxWidth,
      direction: direction,
      strutStyle: strutStyle,
    );

    return paginate(
      lines: lines,
      firstPageHeight: firstPageHeight ?? pageHeight,
      pageHeight: pageHeight,
      paragraphSpacing: paragraphSpacing,
    );
  }
}
