import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/models/reading_background.dart';
import 'package:yunchuang/theme/app_theme.dart';
import 'package:yunchuang/theme/reader_theme.dart';

void main() {
  final base = AppTheme.lightTheme;

  test('跟随主题这一档原样返回，不做任何覆盖', () {
    expect(readerThemeFor(base, ReaderPaper.followTheme), same(base));
  });

  test('纸张底色与字色顶掉 surface / onSurface', () {
    final paper = ReaderPaper.presetById('ink')!;
    final theme = readerThemeFor(base, paper);

    expect(theme.colorScheme.surface, paper.background);
    expect(theme.colorScheme.onSurface, paper.foreground);
    // 纸张色由阅读器里的 AppBackground 画，Scaffold 保持透明，否则背景装饰
    // 在阅读页就看不见了。
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
  });

  // AppTheme 是用 `.apply(bodyColor: ...)` 把字色写进 textTheme 的，只改
  // colorScheme 的话正文会留在旧主题的颜色上——黑纸配深棕字，什么都看不见。
  test('textTheme 的字色跟着纸张一起换', () {
    final paper = ReaderPaper.presetById('ink')!;
    final theme = readerThemeFor(base, paper);

    expect(base.textTheme.bodyMedium?.color, isNot(paper.foreground));
    expect(theme.textTheme.bodyMedium?.color, paper.foreground);
    expect(theme.textTheme.titleLarge?.color, paper.foreground);
  });

  test('深色纸把亮度翻过去，强调色改用夜间那一套', () {
    final theme = readerThemeFor(base, ReaderPaper.presetById('charcoal')!);

    expect(base.brightness, Brightness.light);
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.brightness, Brightness.dark);
    // 浅色主题的 primary 是深棕，压在暗灰纸上几乎看不见。
    expect(theme.colorScheme.primary, AppTheme.darkTheme.colorScheme.primary);
  });

  test('浅色纸在夜间主题下同样把强调色换成日间那一套', () {
    final theme = readerThemeFor(
      AppTheme.darkTheme,
      ReaderPaper.presetById('paperWhite')!,
    );

    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, AppTheme.lightTheme.colorScheme.primary);
  });

  // 工具栏、目录面板、快捷设置都靠这几档拉开层次。方向反了，深色纸上的
  // 面板会比正文还暗，糊成一片。
  test('容器层级始终朝字色方向递进', () {
    for (final paper in ReaderPaper.presets) {
      if (paper.followsTheme) continue;
      final scheme = readerThemeFor(base, paper).colorScheme;
      final tiers = [
        scheme.surfaceContainerLowest,
        scheme.surfaceContainerLow,
        scheme.surfaceContainer,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
      ];
      var previous = ReaderPaper.contrastRatio(tiers.first, paper.background!);
      for (final tier in tiers.skip(1)) {
        final ratio = ReaderPaper.contrastRatio(tier, paper.background!);
        expect(
          ratio,
          greaterThanOrEqualTo(previous),
          reason: '${paper.label} 的容器层级没有单调递进',
        );
        previous = ratio;
      }
    }
  });

  group('设置界面的预览取色', () {
    // 「阅读偏好」和阅读器快捷设置以前各写死了一组预览色（sepia #F5F0E1、
    // dark #1E1E1E），和三套主题真正的 surface（#FFFBF0、#2D2D2D）根本对不
    // 上——预览显示的从来就不是实际读到的颜色。
    test('跟随主题时用主题真正的 surface，不是另写一份色值', () {
      for (final entry in {
        'light': AppTheme.lightTheme,
        'sepia': AppTheme.sepiaTheme,
        'dark': AppTheme.darkTheme,
      }.entries) {
        final preview = readerPreviewColors(
          themeName: entry.key,
          paper: ReaderPaper.followTheme,
          platformBrightness: Brightness.light,
        );
        expect(preview.background, entry.value.colorScheme.surface,
            reason: entry.key);
        expect(preview.foreground, entry.value.colorScheme.onSurface,
            reason: entry.key);
      }
    });

    test('system 跟着系统亮度走', () {
      expect(
        readerPreviewColors(
          themeName: 'system',
          paper: ReaderPaper.followTheme,
          platformBrightness: Brightness.dark,
        ).background,
        AppTheme.darkTheme.colorScheme.surface,
      );
      expect(
        readerPreviewColors(
          themeName: 'system',
          paper: ReaderPaper.followTheme,
          platformBrightness: Brightness.light,
        ).background,
        AppTheme.lightTheme.colorScheme.surface,
      );
    });

    test('选了纸张就以纸张为准，不看主题', () {
      final ink = ReaderPaper.presetById('ink')!;
      final preview = readerPreviewColors(
        themeName: 'light',
        paper: ink,
        platformBrightness: Brightness.light,
      );

      expect(preview.background, ink.background);
      expect(preview.foreground, ink.foreground);
    });
  });

  test('每张纸上正文与次级文字都达到 WCAG AA', () {
    for (final paper in ReaderPaper.presets) {
      if (paper.followsTheme) continue;
      final scheme = readerThemeFor(base, paper).colorScheme;

      expect(
        ReaderPaper.contrastRatio(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(4.5),
        reason: '${paper.label} 正文对比不足',
      );
      expect(
        ReaderPaper.contrastRatio(
          scheme.onSurfaceVariant,
          scheme.surfaceContainerHighest,
        ),
        greaterThanOrEqualTo(4.5),
        reason: '${paper.label} 次级文字对比不足',
      );
    }
  });
}
