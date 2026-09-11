import 'package:flutter/material.dart';

import '../models/reading_background.dart';
import 'app_theme.dart';

/// 把选中的[纸张][ReaderPaper]铺进一份 [ThemeData]，供阅读器子树使用。
///
/// 阅读器上下几十个部件都是从 `colorScheme.surface` / `onSurface` 取色的
/// （正文、工具栏、目录面板、快捷设置、TTS 面板……）。所以正文换底色不必
/// 给每个部件新加一个参数——覆盖它们共同的来源就够了，工具栏和面板还会自动
/// 跟着换，不会出现「黑底正文 + 白色目录弹层」这种夜里刺眼的跳变。
ThemeData readerThemeFor(ThemeData base, ReaderPaper paper) {
  final background = paper.background;
  final foreground = paper.foreground;
  if (background == null || foreground == null) return base;

  // 强调色跟着纸张的明暗走，而不是跟着全局主题。浅色主题里的 primary 是深
  // 棕（#8F5D3D），压在纯黑纸上几乎看不见；反过来夜间主题的浅棕在白纸上
  // 同样发虚。按纸张亮度挑一套，进度条、选中态才有对比。
  final paperIsDark = background.computeLuminance() < 0.5;
  final accents = paperIsDark ? AppTheme.darkScheme : AppTheme.lightScheme;

  Color toward(Color target, double amount) =>
      Color.lerp(background, target, amount)!;
  Color softText(double amount) => Color.lerp(foreground, background, amount)!;

  // 次级文字最常出现在最高一档容器上（工具栏、目录面板的副标题），底色比
  // 正文区更靠近字色，对比天然更窄。所以淡化程度不能写死：从 0.28 往回收，
  // 直到压在那一档上仍然达到 WCAG AA。米白纸按 0.28 只有 4.32:1。
  final containerHighest = toward(foreground, 0.15);
  var variantSoftness = 0.28;
  while (variantSoftness > 0 &&
      ReaderPaper.contrastRatio(softText(variantSoftness), containerHighest) <
          4.5) {
    variantSoftness -= 0.02;
  }

  final scheme = accents.copyWith(
    brightness: paperIsDark ? Brightness.dark : Brightness.light,
    surface: background,
    onSurface: foreground,
    onSurfaceVariant: softText(variantSoftness.clamp(0.0, 0.28)),
    // 层级由「往字色方向混」得到，因此在任何纸张上都朝同一方向拉开，不用
    // 为浅色纸和深色纸各写一套。
    surfaceContainerLowest: background,
    surfaceContainerLow: toward(foreground, 0.03),
    surfaceContainer: toward(foreground, 0.06),
    surfaceContainerHigh: toward(foreground, 0.10),
    surfaceContainerHighest: containerHighest,
    outline: softText(0.55),
    outlineVariant: softText(0.72),
  );

  return base.copyWith(
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    // textTheme 必须一起换：AppTheme 是用 `.apply(bodyColor: ...)` 把字色写死
    // 进去的，只改 colorScheme 的话正文会保持旧主题的颜色。
    textTheme: base.textTheme.apply(
      bodyColor: foreground,
      displayColor: foreground,
    ),
    primaryTextTheme: base.primaryTextTheme.apply(
      bodyColor: foreground,
      displayColor: foreground,
    ),
    iconTheme: base.iconTheme.copyWith(color: foreground),
    dividerColor: scheme.outlineVariant,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: background,
      foregroundColor: foreground,
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        color: foreground,
      ),
      iconTheme: IconThemeData(color: foreground),
    ),
    cardTheme: base.cardTheme.copyWith(color: scheme.surfaceContainerLow),
    // AI 面板、翻译弹层的输入框都在阅读器子树里（都是 useRootNavigator: false
    // 的 modal sheet，会继承这层 Theme）。AppTheme 把 fillColor 写死成了各自
    // 主题的 surface，不换的话黑纸上会冒出一个白色输入框。
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: scheme.surfaceContainerLow,
      border: _readerInputBorder(scheme.outlineVariant),
      enabledBorder: _readerInputBorder(scheme.outlineVariant),
      focusedBorder: _readerInputBorder(scheme.primary, width: 2),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.primaryContainer,
      labelStyle: base.chipTheme.labelStyle?.copyWith(color: foreground),
      secondaryLabelStyle: base.chipTheme.secondaryLabelStyle
          ?.copyWith(color: scheme.onPrimaryContainer),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 18),
      side: BorderSide(color: scheme.outlineVariant),
    ),
  );
}

OutlineInputBorder _readerInputBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: width),
  );
}

/// 阅读页实际会看到的底色与字色，供设置界面的预览使用。
///
/// 之前「阅读偏好」和阅读器内的快捷设置各写死了一组色值（sepia #F5F0E1、
/// dark #1E1E1E），和三套主题真正的 surface（#FFFBF0、#2D2D2D）对不上——
/// 预览显示的从来就不是实际读到的颜色。现在两处都走这里，且纸张优先。
({Color background, Color foreground}) readerPreviewColors({
  required String themeName,
  required ReaderPaper paper,
  required Brightness platformBrightness,
}) {
  final background = paper.background;
  final foreground = paper.foreground;
  if (background != null && foreground != null) {
    return (background: background, foreground: foreground);
  }
  final scheme = AppTheme.resolveScheme(themeName, platformBrightness);
  return (background: scheme.surface, foreground: scheme.onSurface);
}
