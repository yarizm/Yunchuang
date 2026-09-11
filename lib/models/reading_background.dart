import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 应用全局背景的样式。
///
/// 背景层此前是写死的（深棕底 + 粉蓝渐变 + 水彩插画常驻），而且被套在
/// `MaterialApp` 外面——拿不到 `Theme.of(context)`，三套主题下长得一模一样。
/// 日间主题因此是「白色顶栏压在深棕插画上」，书籍网格区更是整片露出插画。
/// 这个枚举把背景变成一项显式偏好，配合 `AppBackground` 按当前配色方案取色。
enum AppBackgroundStyle {
  /// 纯色，直接用当前主题的 surface。最省电，也最不干扰内容。
  solid('solid', '纯色'),

  /// 由主题色推出的流动渐变。
  gradient('gradient', '流动渐变'),

  /// 内置水彩书斋插画。
  illustration('illustration', '书斋插画'),

  /// 用户自选图片。
  custom('custom', '自定义图片');

  final String storageValue;
  final String label;

  const AppBackgroundStyle(this.storageValue, this.label);

  static AppBackgroundStyle fromStorage(String? value) {
    for (final style in values) {
      if (style.storageValue == value) return style;
    }
    return AppBackgroundStyle.solid;
  }
}

/// 正文纸张：底色与字色成对出现。
///
/// 拆出来单独存，是因为「读什么颜色的纸」和「应用是亮是暗」本来就是两件事。
/// 此前正文底色直接取 `colorScheme.surface`，想要黑底白字就只能把整个应用
/// 切成夜间主题，连书架和设置页一起变暗。
@immutable
class ReaderPaper {
  final String id;
  final String label;

  /// null 表示跟随全局主题，由 `colorScheme` 决定。
  final Color? background;
  final Color? foreground;

  const ReaderPaper({
    required this.id,
    required this.label,
    this.background,
    this.foreground,
  });

  bool get followsTheme => background == null;

  /// 跟随全局主题——不覆盖任何颜色。
  static const followTheme = ReaderPaper(id: 'theme', label: '跟随主题');

  /// 预设纸张。底色按「白 → 暖 → 绿 → 灰 → 黑」排，方便在设置里横向扫。
  ///
  /// 字色不用纯黑纯白：纯白压在纯黑上会晕开（halation），纯黑压在暖色纸上
  /// 又太硬。每档都取了同色系里偏暖的近黑 / 近白。
  static const presets = <ReaderPaper>[
    followTheme,
    ReaderPaper(
      id: 'paperWhite',
      label: '纸白',
      background: Color(0xFFFFFFFF),
      foreground: Color(0xFF1F1B18),
    ),
    ReaderPaper(
      id: 'rice',
      label: '米白',
      background: Color(0xFFFAF6ED),
      foreground: Color(0xFF2E2520),
    ),
    ReaderPaper(
      id: 'almond',
      label: '杏仁',
      background: Color(0xFFF2E8D5),
      foreground: Color(0xFF3B3020),
    ),
    ReaderPaper(
      id: 'eyecare',
      label: '豆绿',
      background: Color(0xFFE3EDE0),
      foreground: Color(0xFF22301F),
    ),
    ReaderPaper(
      id: 'mist',
      label: '灰蓝',
      background: Color(0xFFDDE3E8),
      foreground: Color(0xFF1E262C),
    ),
    ReaderPaper(
      id: 'charcoal',
      label: '暗灰',
      background: Color(0xFF2A2A2E),
      foreground: Color(0xFFD6D3CE),
    ),
    ReaderPaper(
      id: 'ink',
      label: '纯黑',
      background: Color(0xFF000000),
      foreground: Color(0xFFB8B4AE),
    ),
  ];

  static ReaderPaper? presetById(String? id) {
    if (id == null) return null;
    for (final paper in presets) {
      if (paper.id == id) return paper;
    }
    return null;
  }

  /// 自定义底色。字色不让用户单独选，按对比度推——见 [foregroundFor]。
  factory ReaderPaper.custom(Color background) => ReaderPaper(
        id: customId,
        label: '自定义',
        background: background,
        foreground: foregroundFor(background),
      );

  static const customId = 'custom';

  /// WCAG 相对对比度。
  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// 推导能与 [background] 拉开足够对比的正文字色。
  ///
  /// 可读性下限由末尾的纯黑 / 纯白兜底保证，不是靠这段循环：纯黑要求底色
  /// 相对亮度 ≥ 0.175，纯白要求 ≤ 0.1833，两段区间是重叠的，所以任何底色
  /// 都至少有一个达标（最差的一档在亮度 0.179 处，仍有 4.585:1）。
  ///
  /// 循环要解决的是另一件事：**别把兜底色用出来**。纯黑压在暖色纸上太硬，
  /// 纯白压在纯黑上会晕开（halation）。所以先带着底色的色相往对比大的一侧
  /// 推，找到第一个仍然达标的柔和色；实测预设和常见自选色两三步内就命中，
  /// 兜底只在极端配色下才会触发。
  static Color foregroundFor(Color background) {
    final hsl = HSLColor.fromColor(background);
    final goDark = background.computeLuminance() > 0.18;
    final saturation = math.min(hsl.saturation * 0.5, 0.22);

    var lightness = goDark ? 0.16 : 0.84;
    Color candidate() => hsl
        .withSaturation(saturation)
        .withLightness(lightness.clamp(0.0, 1.0))
        .toColor();

    // 每步 2% 明度，最多走完整条轴。
    for (var step = 0; step < 50; step++) {
      final color = candidate();
      if (contrastRatio(color, background) >= 4.5) return color;
      lightness += goDark ? -0.02 : 0.02;
      if (lightness < 0 || lightness > 1) break;
    }
    // 带色相的柔和色全程都不达标，退回纯黑 / 纯白里对比更大的那个。见上面
    // 的说明：这一步必定达标，是整个函数的可读性下限。
    const black = Color(0xFF000000);
    const white = Color(0xFFFFFFFF);
    return contrastRatio(black, background) >= contrastRatio(white, background)
        ? black
        : white;
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderPaper &&
      other.id == id &&
      other.background == background &&
      other.foreground == foreground;

  @override
  int get hashCode => Object.hash(id, background, foreground);
}
