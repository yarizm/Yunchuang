import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/models/reading_background.dart';

void main() {
  group('AppBackgroundStyle', () {
    test('每个样式都能按存储值原样取回', () {
      for (final style in AppBackgroundStyle.values) {
        expect(AppBackgroundStyle.fromStorage(style.storageValue), style);
      }
    });

    test('认不出来的值退回纯色，而不是抛异常', () {
      // 降级安装、手改 prefs、将来删掉某个样式，都会走到这里。背景认不出来
      // 不该让应用起不来。
      expect(AppBackgroundStyle.fromStorage(null), AppBackgroundStyle.solid);
      expect(AppBackgroundStyle.fromStorage(''), AppBackgroundStyle.solid);
      expect(
        AppBackgroundStyle.fromStorage('parallax3d'),
        AppBackgroundStyle.solid,
      );
    });
  });

  group('ReaderPaper', () {
    test('跟随主题这一档不带任何颜色', () {
      expect(ReaderPaper.followTheme.followsTheme, isTrue);
      expect(ReaderPaper.followTheme.background, isNull);
      expect(ReaderPaper.followTheme.foreground, isNull);
    });

    test('每张预设纸的字色都达到 WCAG AA', () {
      for (final paper in ReaderPaper.presets) {
        if (paper.followsTheme) continue;
        expect(
          ReaderPaper.contrastRatio(paper.foreground!, paper.background!),
          greaterThanOrEqualTo(4.5),
          reason: '${paper.label} 的字色压在底色上看不清',
        );
      }
    });

    test('presetById 认得每张预设，认不出的返回 null', () {
      for (final paper in ReaderPaper.presets) {
        expect(ReaderPaper.presetById(paper.id), paper);
      }
      expect(ReaderPaper.presetById(null), isNull);
      expect(ReaderPaper.presetById('nope'), isNull);
    });

    // 自定义底色是用户随便点出来的，字色由 foregroundFor 推。这里把整个
    // RGB 空间粗筛一遍，钉住「任何底色都有可读性下限」这条保证。
    test('任意底色推出的字色都达到 WCAG AA', () {
      final failures = <String>[];
      for (var r = 0; r <= 255; r += 15) {
        for (var g = 0; g <= 255; g += 15) {
          for (var b = 0; b <= 255; b += 15) {
            final background = Color.fromARGB(255, r, g, b);
            final ratio = ReaderPaper.contrastRatio(
              ReaderPaper.foregroundFor(background),
              background,
            );
            if (ratio < 4.5) {
              failures.add('#${r.toRadixString(16)}'
                  '${g.toRadixString(16)}${b.toRadixString(16)} → $ratio');
            }
          }
        }
      }
      expect(failures, isEmpty);
    });

    // 上面那条只证明「达标」，而纯黑 / 纯白兜底本身就必定达标（纯黑要求底色
    // 亮度 ≥ 0.175，纯白要求 ≤ 0.1833，两段重叠）。所以它管不住明度推导那段
    // 循环——把循环删了它照样绿。真正要钉住的是「别把兜底色用出来」：常见
    // 底色上应该得到一个带色相的柔和字色，而不是硬邦邦的纯黑纯白。
    // 这几个饱和中间调，第一个候选色（明度 0.16 / 0.84）都不达标，必须靠
    // 循环继续推才找得到答案——把循环砍成一次，它们就会掉进兜底色。无彩色
    // 的灰不能进这一组：灰没有色相可带，#767676 的正确答案本来就是纯黑。
    test('饱和中间调靠明度推导找到柔和字色，不掉进兜底', () {
      const black = Color(0xFF000000);
      const white = Color(0xFFFFFFFF);
      const backgrounds = [
        Color(0xFF0055CC), // 中蓝
        Color(0xFF0066AA), // 青蓝
        Color(0xFF3A5F4B), // 深绿
        Color(0xFF8B2F3A), // 暗红
      ];
      for (final background in backgrounds) {
        final foreground = ReaderPaper.foregroundFor(background);
        expect(
          ReaderPaper.contrastRatio(foreground, background),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          foreground,
          isNot(anyOf(black, white)),
          reason: '$background 退到了兜底色，明度推导没起作用',
        );
      }
    });

    // 无彩色底色只保证下限。灰底上没有色相可保留，推到底就是纯黑纯白，
    // 这不是缺陷。
    test('中等灰底也能达标', () {
      for (final gray in const [
        Color(0xFF767676),
        Color(0xFF808080),
        Color(0xFF949494),
      ]) {
        expect(
          ReaderPaper.contrastRatio(ReaderPaper.foregroundFor(gray), gray),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('字色带上底色的色相', () {
      final warm = ReaderPaper.foregroundFor(const Color(0xFFF2E8D5));
      expect(warm.r, greaterThan(warm.b), reason: '暖色纸上的字色应偏暖');

      final cool = ReaderPaper.foregroundFor(const Color(0xFFDDE3E8));
      expect(cool.b, greaterThan(cool.r), reason: '冷色纸上的字色应偏冷');
    });

    test('自定义纸把底色记下来并配好字色', () {
      const picked = Color(0xFF3A5F4B);
      final paper = ReaderPaper.custom(picked);

      expect(paper.id, ReaderPaper.customId);
      expect(paper.background, picked);
      expect(
        ReaderPaper.contrastRatio(paper.foreground!, picked),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
