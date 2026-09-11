import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/theme/app_theme.dart';

void main() {
  final themes = <String, ThemeData>{
    '日间': AppTheme.lightTheme,
    '护眼': AppTheme.sepiaTheme,
    '夜间': AppTheme.darkTheme,
  };

  for (final entry in themes.entries) {
    test('${entry.key}主题文字达到 WCAG 对比度要求', () {
      final scheme = entry.value.colorScheme;

      expect(
        _contrastRatio(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          scheme.onSurfaceVariant,
          scheme.surfaceContainerHighest,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('${entry.key}主题稳定表面在极端底色上保持文字可读', () {
      final scheme = entry.value.colorScheme;
      final stableSurface = scheme.surface.withValues(
        alpha: entry.value.brightness == Brightness.dark ? 0.94 : 0.96,
      );

      for (final backdrop in const [Colors.black, Colors.white]) {
        final composed = Color.alphaBlend(stableSurface, backdrop);
        expect(
          _contrastRatio(scheme.onSurface, composed),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(scheme.onSurfaceVariant, composed),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  }

  test('common page app bars use opaque themed surfaces', () {
    for (final theme in themes.values) {
      expect(
        theme.appBarTheme.backgroundColor,
        theme.colorScheme.surface,
      );
    }
  });

  for (final entry in themes.entries) {
    test('${entry.key}主题 chip 配色取自同一份 ColorScheme', () {
      final theme = entry.value;
      final scheme = theme.colorScheme;
      final chip = theme.chipTheme;

      expect(chip.backgroundColor, scheme.surfaceContainerHigh);
      expect(chip.selectedColor, scheme.primaryContainer);
      expect(chip.labelStyle?.color, scheme.onSurface);
      expect(chip.secondaryLabelStyle?.color, scheme.onPrimaryContainer);
      expect(chip.iconTheme?.color, scheme.onSurfaceVariant);
      expect(chip.side?.color, scheme.outlineVariant);
    });
  }

  // resolveScheme 存在的意义是「不构造 ThemeData 就能拿到配色」——预览每帧
  // 都要用。两份映射各写各的就会慢慢对不上，这里钉死它们一致。
  test('resolveScheme 与 resolve 的配色始终一致', () {
    for (final name in const ['light', 'sepia', 'dark', 'system', '乱写的']) {
      for (final brightness in Brightness.values) {
        expect(
          AppTheme.resolveScheme(name, brightness),
          AppTheme.resolve(name, brightness).colorScheme,
          reason: '$name / $brightness',
        );
      }
    }
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter =
      firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker =
      firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
