import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/typography/text_measurer.dart';

/// 排版内核第 2 步验证（docs/plans/2026-08-16-typesetting-kernel-v1.md）：
/// 对比同一文本/样式下三个变体的高度与行数——
///
/// - A：TextPainter 无 strut（FlutterTextMeasurer 现状）
/// - B：TextPainter 带渲染端实际 strut（从 RenderEditable.strutStyle 读回）
/// - C：SelectableText.rich 实际渲染高度
///
/// 结论（2026-08-22，Windows + SimHei/Arial 实测）：
/// - style.height 非空且文本较短（数百字符内）时，A == B == C 精确相等，
///   含加粗、拉丁主字体 + CJK fallback 场景。
/// - style.height 为 null 时（生产不存在此配置，lineHeight 恒非空），渲染
///   端更高：EditableText 的默认 strut（StrutStyle.fromTextStyle +
///   forceStrutHeight，height 缺省时以 1.4x 为最小行高）抬高每一行。
/// - **长文本存在不可归因的断行差异**：同一文本 TextPainter 与
///   RenderEditable 在宽度边界处断行相差一个字符，累积后渲染端多断行
///   ——中文每页多一行（693 字符：度量 17 行，渲染 18 行）；西文按词
///   断行加句级 span 拆分可差两行（500 句拉丁文本实测）。SimHei 与
///   测试字体均如此，strut/字体均已排除。paged_reader 因此保留两行
///   余量（同旧 layoutSlack），待接管渲染后移除。
///
/// 差异来自真实字体 metrics，故加载 Windows 系统字体；字体缺失的环境
/// （CI ubuntu）整组跳过。
const _cjkFontPath = r'C:\Windows\Fonts\simhei.ttf';
const _latinFontPath = r'C:\Windows\Fonts\arial.ttf';

const _probeText =
    '简体中文与English混排的正文段落，需要足够长以便断成多行，包含数字1234567890与标点、逗号，'
    '以及 ending with latin words that wrap across lines naturally.';
const _probeWidth = 300.0;

final bool _fontsAvailable =
    File(_cjkFontPath).existsSync() && File(_latinFontPath).existsSync();

Future<void> _loadFont(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

class _ProbeResult {
  const _ProbeResult({
    required this.plainHeight,
    required this.plainLines,
    required this.strutHeight,
    required this.strutLines,
    required this.renderedHeight,
    required this.renderedLines,
    required this.actualStrut,
  });

  final double plainHeight;
  final int plainLines;
  final double strutHeight;
  final int strutLines;
  final double renderedHeight;
  final int renderedLines;
  final StrutStyle? actualStrut;

  @override
  String toString() =>
      'A无strut=${plainHeight.toStringAsFixed(2)}/$plainLines行 '
      'B带strut=${strutHeight.toStringAsFixed(2)}/$strutLines行 '
      'C渲染=${renderedHeight.toStringAsFixed(2)}/$renderedLines行 '
      'strut=$actualStrut';
}

Future<_ProbeResult> _probeCase(
  WidgetTester tester,
  TextStyle style, {
  String text = _probeText,
  double width = _probeWidth,
}) async {
  const measurer = FlutterTextMeasurer();

  final plainLines = measurer.layout(
    text: text,
    style: style,
    maxWidth: width,
    direction: TextDirection.ltr,
  );
  final plainHeight = plainLines.fold(0.0, (sum, line) => sum + line.height);

  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: SelectableText.rich(
              TextSpan(text: text),
              key: key,
              style: style,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final editable = _findRenderEditable(key);
  if (editable == null) {
    throw StateError('未找到 RenderEditable');
  }
  final renderedHeight = editable.size.height;
  final actualStrut = editable.strutStyle;

  final strutLines = actualStrut == null
      ? plainLines
      : measurer.layout(
          text: text,
          style: style,
          maxWidth: width,
          direction: TextDirection.ltr,
          strutStyle: actualStrut,
        );
  final strutHeight = strutLines.fold(0.0, (sum, line) => sum + line.height);
  final renderedLines = (renderedHeight / editable.preferredLineHeight).round();

  return _ProbeResult(
    plainHeight: plainHeight,
    plainLines: plainLines.length,
    strutHeight: strutHeight,
    strutLines: strutLines.length,
    renderedHeight: renderedHeight,
    renderedLines: renderedLines,
    actualStrut: actualStrut,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!_fontsAvailable) return;
    await _loadFont('TestCJK', _cjkFontPath);
    await _loadFont('TestLatin', _latinFontPath);
  });

  testWidgets(
    'height 非空（生产路径）：SelectableText.rich 渲染高度与 TextPainter 度量精确一致',
    (tester) async {
      const cases = <(String, TextStyle)>[
        ('16/1.6 默认', TextStyle(fontSize: 16, height: 1.6, fontFamily: 'TestCJK')),
        ('16/1.2 紧行高', TextStyle(fontSize: 16, height: 1.2, fontFamily: 'TestCJK')),
        ('16/2.0 松行高', TextStyle(fontSize: 16, height: 2.0, fontFamily: 'TestCJK')),
        (
          '16/1.6 加粗',
          TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.w600, fontFamily: 'TestCJK')
        ),
        ('20/1.5', TextStyle(fontSize: 20, height: 1.5, fontFamily: 'TestCJK')),
        (
          '16/1.6 拉丁主字体 + CJK fallback',
          TextStyle(fontSize: 16, height: 1.6, fontFamily: 'TestLatin', fontFamilyFallback: ['TestCJK'])
        ),
        (
          '20/1.8 与 paged_reader 默认一致',
          TextStyle(fontSize: 18, height: 1.8, fontFamily: 'TestCJK')
        ),
      ];

      for (final (name, style) in cases) {
        final result = await _probeCase(tester, style);
        // ignore: avoid_print, 诊断输出：结论依据，保留便于复核。
        print('[$name] $result');

        expect(
          result.renderedHeight,
          anyOf(
            closeTo(result.plainHeight, 0.5),
            closeTo(result.strutHeight, 0.5),
          ),
          reason: '[$name] SelectableText 渲染 $result —— 与 A/B 均不一致',
        );
      }
    },
    // 无 Windows 字体的环境（CI ubuntu）跳过：差异来自真实字体 metrics。
    skip: !_fontsAvailable,
  );

  testWidgets(
    '已知差异：height 为 null 时渲染端更高（EditableText 默认 strut），生产路径不受影响',
    (tester) async {
      const cases = <(String, TextStyle)>[
        ('16 无 height', TextStyle(fontSize: 16, fontFamily: 'TestCJK')),
        (
          '16 无 height 拉丁主字体 + CJK fallback',
          TextStyle(fontSize: 16, fontFamily: 'TestLatin', fontFamilyFallback: ['TestCJK'])
        ),
      ];

      for (final (name, style) in cases) {
        final result = await _probeCase(tester, style);
        // ignore: avoid_print, 诊断输出：结论依据，保留便于复核。
        print('[$name] $result');

        expect(
          result.renderedHeight,
          greaterThan(result.plainHeight),
          reason: '[$name] height 为 null 时渲染端应高于度量'
              '（EditableText 默认 strut 的最小行高）——若变为一致，'
              '请回到本文件更新头部结论注释。',
        );
      }
    },
    skip: !_fontsAvailable,
  );

  testWidgets(
    '已知差异：长文本渲染比度量至多多断一行（paged_reader 据此预留一行余量）',
    (tester) async {
      // 扩大视口，避免长文本渲染高度被默认 600px 屏幕约束截断。
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final full = '分页模式应当左右翻页，而不是上下滚动。' * 1000;
      const style = TextStyle(
        fontSize: 18,
        height: 1.8,
        letterSpacing: 0.5,
        fontFamily: 'TestCJK',
      );

      for (final length in [500, 693, 800]) {
        final result = await _probeCase(
          tester,
          style,
          text: full.substring(0, length),
          width: 760,
        );
        // ignore: avoid_print, 诊断输出：结论依据，保留便于复核。
        print('[长文本/$length] $result');

        // 中文长文本：断行微差累积后渲染端多出至多一行（西文按词断行
        // 场景可到两行，paged_reader 的两行余量据此保留）。
        expect(
          result.renderedHeight,
          allOf(
            greaterThanOrEqualTo(result.plainHeight - 0.5),
            lessThanOrEqualTo(
                result.plainHeight + style.fontSize! * style.height! * 1.2),
          ),
          reason: '[长文本/$length] 渲染高度超出了「度量 + 一行」的范围',
        );
      }
    },
    skip: !_fontsAvailable,
  );
}

RenderEditable? _findRenderEditable(GlobalKey key) {
  final root = key.currentContext?.findRenderObject();
  if (root is RenderEditable) return root;
  RenderEditable? found;
  void visit(RenderObject node) {
    if (found != null) return;
    if (node is RenderEditable) {
      found = node;
      return;
    }
    node.visitChildren(visit);
  }

  if (root != null) visit(root);
  return found;
}
