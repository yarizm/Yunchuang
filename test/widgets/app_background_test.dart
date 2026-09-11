import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/models/reading_background.dart';
import 'package:yunchuang/theme/app_theme.dart';
import 'package:yunchuang/widgets/app_background.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required ThemeData theme,
    AppBackgroundStyle style = AppBackgroundStyle.solid,
    double intensity = 0.25,
    String? customImagePath,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) => AppBackground(
            style: style,
            intensity: intensity,
            customImagePath: customImagePath,
            animationEnabled: false,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  bool paintsBase(WidgetTester tester, Color color) => tester
      .widgetList<ColoredBox>(find.byType(ColoredBox))
      .any((box) => box.color == color);

  // 这是「色调有问题」的根因所在：背景以前包在 MaterialApp 外面，取不到
  // Theme.of(context)，三套主题下都是那一片写死的深棕（#2C2118）。
  group('底色跟随主题', () {
    testWidgets('日间主题下用日间的 surface', (tester) async {
      await pump(tester, theme: AppTheme.lightTheme);

      expect(paintsBase(tester, AppTheme.lightTheme.colorScheme.surface),
          isTrue);
      expect(paintsBase(tester, const Color(0xFF2C2118)), isFalse);
    });

    testWidgets('夜间主题下换成夜间的 surface', (tester) async {
      await pump(tester, theme: AppTheme.darkTheme);

      expect(
          paintsBase(tester, AppTheme.darkTheme.colorScheme.surface), isTrue);
      expect(paintsBase(tester, AppTheme.lightTheme.colorScheme.surface),
          isFalse);
    });

    testWidgets('护眼主题下换成护眼的 surface', (tester) async {
      await pump(tester, theme: AppTheme.sepiaTheme);

      expect(
          paintsBase(tester, AppTheme.sepiaTheme.colorScheme.surface), isTrue);
    });
  });

  group('装饰层', () {
    testWidgets('纯色不画任何装饰', (tester) async {
      await pump(tester, theme: AppTheme.lightTheme);

      expect(find.byType(Image), findsNothing);
      expect(find.byType(DecoratedBox), findsNothing);
    });

    testWidgets('插画样式画出内置图片', (tester) async {
      await pump(
        tester,
        theme: AppTheme.lightTheme,
        style: AppBackgroundStyle.illustration,
      );

      expect(find.byType(Image), findsOneWidget);
      // 底色仍然在，插画只是叠上去的一层。
      expect(paintsBase(tester, AppTheme.lightTheme.colorScheme.surface),
          isTrue);
    });

    // 浓度拉到 0 就该完全等于纯色，不留一层白开销。
    testWidgets('浓度为 0 时装饰层整个不建', (tester) async {
      await pump(
        tester,
        theme: AppTheme.lightTheme,
        style: AppBackgroundStyle.illustration,
        intensity: 0,
      );

      expect(find.byType(Image), findsNothing);
    });

    // 走 Image 自带的 opacity，不套 Opacity 部件：后者会为整屏开一层离屏
    // 缓冲（saveLayer），而这层背景在每一屏后面都在。
    testWidgets('浓度直接决定装饰层的不透明度，且不引入 Opacity 部件', (tester) async {
      await pump(
        tester,
        theme: AppTheme.lightTheme,
        style: AppBackgroundStyle.illustration,
        intensity: 0.4,
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.opacity?.value, 0.4);
      expect(
        find.ancestor(of: find.byType(Image), matching: find.byType(Opacity)),
        findsNothing,
      );
    });
  });

  group('自定义图片', () {
    // 「文件在就画出来」这条不在这里测：FileImage 读盘是真异步的，在
    // testWidgets 的 fake async 时间轴里永远完不成，测试会挂住不返回
    // （runAsync 也救不回来，还会把同文件后面的用例一起拖死）。这个判断的
    // 真正决策点在 customBackgroundPathProvider——文件在不在由它决定，见
    // test/providers/custom_background_path_test.dart。这里只钉住反面：
    // 拿不到有效路径时必须安静退回纯色。
    // 换过设备、恢复了一份不含背景图的老备份、用户在系统里删了文件——
    // 偏好还指着它。这时候要安静退回纯色，不能崩。
    testWidgets('文件不在就退回纯色', (tester) async {
      await pump(
        tester,
        theme: AppTheme.lightTheme,
        style: AppBackgroundStyle.custom,
        customImagePath: '/definitely/not/here.png',
      );

      expect(find.byType(Image), findsNothing);
      expect(paintsBase(tester, AppTheme.lightTheme.colorScheme.surface),
          isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('路径为空也不崩', (tester) async {
      await pump(
        tester,
        theme: AppTheme.lightTheme,
        style: AppBackgroundStyle.custom,
      );

      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
